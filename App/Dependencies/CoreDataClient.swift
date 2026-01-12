import ComposableArchitecture
import CoreData
import Foundation

@DependencyClient
struct CoreDataClient: Sendable {
  var getFiles: @Sendable () async throws -> [File] = { [] }
  var getFile: @Sendable (_ fileId: String) async throws -> File? = { _ in nil }
  var cacheFiles: @Sendable ([File]) async throws -> Void
  var cacheFile: @Sendable (File) async throws -> Void
  var updateFileUrl: @Sendable (_ fileId: String, _ url: URL) async throws -> Void
  var updateFileStatus: @Sendable (_ fileId: String, _ status: FileStatus) async throws -> Void
  var saveContext: @Sendable () async throws -> Void
  var truncateFiles: @Sendable () async throws -> Void
  var deleteFile: @Sendable (File) async throws -> Void
  // Metrics
  var getMetrics: @Sendable () async throws -> FileMetrics = { .zero }
  var markFileDownloaded: @Sendable (_ fileId: String) async throws -> Void
  var incrementPlayCount: @Sendable () async throws -> Void
  var resetMetrics: @Sendable () async throws -> Void
}

extension DependencyValues {
  var coreDataClient: CoreDataClient {
    get { self[CoreDataClient.self] }
    set { self[CoreDataClient.self] = newValue }
  }
}

enum CoreDataError: Error {
  case fetchFailed(String)
  case saveFailed(String)
  case deleteFailed(String)
}

struct FileMetrics: Equatable {
  var downloadCount: Int
  var totalStorageBytes: Int64
  var playCount: Int

  static let zero = FileMetrics(downloadCount: 0, totalStorageBytes: 0, playCount: 0)
}

// MARK: - Live API implementation
extension CoreDataClient: DependencyKey {
  static let liveValue = CoreDataClient(
    getFiles: {
      let context = PersistenceController.shared.container.viewContext
      return try await context.perform {
        let request = FileEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FileEntity.publishDate, ascending: false)]
        let entities = try context.fetch(request)
        let files = entities.map { FileMapper.fromEntity($0) }
        print("📁 Loaded \(files.count) files from CoreData")
        return files
      }
    },
    getFile: { fileId in
      let context = PersistenceController.shared.container.viewContext
      return try await context.perform {
        let request = FileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "fileId == %@", fileId)
        request.fetchLimit = 1
        guard let entity = try context.fetch(request).first else {
          return nil
        }
        return FileMapper.fromEntity(entity)
      }
    },
    cacheFiles: { files in
      // Use background context for heavy write operations to avoid blocking main thread
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
      
      try await context.perform {
        // Upsert each file (update existing or create new)
        for file in files {
          _ = FileMapper.toEntity(file, in: context)
        }
        try context.save()
        print("📁 Cached \(files.count) files to CoreData (background context)")
      }
    },
    cacheFile: { file in
      // Use background context for write operations
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
      
      try await context.perform {
        _ = FileMapper.toEntity(file, in: context)
        try context.save()
        print("📁 Cached file to CoreData: \(file.fileId)")
      }
    },
    updateFileUrl: { fileId, url in
      // Use background context for write operations
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

      try await context.perform {
        let request = FileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "fileId == %@", fileId)
        request.fetchLimit = 1
        guard let entity = try context.fetch(request).first else {
          print("📁 File not found for URL update: \(fileId)")
          return
        }
        entity.url = url.absoluteString
        try context.save()
        print("📁 Updated URL for file: \(fileId)")
      }
    },
    updateFileStatus: { fileId, status in
      // Use background context for write operations
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

      try await context.perform {
        let request = FileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "fileId == %@", fileId)
        request.fetchLimit = 1
        guard let entity = try context.fetch(request).first else {
          print("📁 File not found for status update: \(fileId)")
          return
        }
        entity.status = status.rawValue
        try context.save()
        print("📁 Updated status for file: \(fileId) to \(status.rawValue)")
      }
    },
    saveContext: {
      let context = PersistenceController.shared.container.viewContext
      try await context.perform {
        if context.hasChanges {
          try context.save()
          print("📁 CoreData context saved")
        }
      }
    },
    truncateFiles: {
      // Delete all downloaded files from Documents directory
      let fileManager = FileManager.default
      guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
      }

      do {
        let files = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
        for file in files {
          // Delete media files (mp4, mp3, etc.)
          let ext = file.pathExtension.lowercased()
          if ["mp4", "mp3", "m4a", "mov", "m4v", "wav", "webm"].contains(ext) {
            print("🗑️ Deleting file: \(file.lastPathComponent)")
            try fileManager.removeItem(at: file)
          }
        }
      } catch {
        print("🗑️ Error deleting media files: \(error)")
      }

      // Also clear all FileEntity records from CoreData (use background context)
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
      
      do {
        try await context.perform {
          let request = NSFetchRequest<NSFetchRequestResult>(entityName: "FileEntity")
          let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
          try context.execute(deleteRequest)
          try context.save()
          print("🗑️ Cleared all FileEntity records from CoreData")
        }
        print("🗑️ Truncate complete")
      } catch {
        print("🗑️ Error clearing CoreData: \(error)")
      }
    },
    deleteFile: { file in
      // Delete specific file from Documents directory
      guard let remoteURL = file.url else { return }
      let fileManager = FileManager.default
      guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
      }
      let localURL = documentsPath.appendingPathComponent(remoteURL.lastPathComponent)
      if fileManager.fileExists(atPath: localURL.path) {
        print("🗑️ Deleting file: \(localURL.lastPathComponent)")
        try fileManager.removeItem(at: localURL)
      }

      // Also delete from CoreData (use background context)
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

      try await context.perform {
        let request = FileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "fileId == %@", file.fileId)
        if let entity = try context.fetch(request).first {
          context.delete(entity)
          try context.save()
          print("🗑️ Deleted FileEntity from CoreData: \(file.fileId)")
        }
      }
    },
    getMetrics: {
      let context = PersistenceController.shared.container.viewContext
      let fileManager = FileManager.default
      guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return .zero
      }

      return try await context.perform {
        // Count downloaded files
        let fileRequest = FileEntity.fetchRequest()
        fileRequest.predicate = NSPredicate(format: "isDownloaded == YES")
        let downloadedFiles = try context.fetch(fileRequest)
        let downloadCount = downloadedFiles.count

        // Calculate storage from actual files on disk
        var totalBytes: Int64 = 0
        for entity in downloadedFiles {
          if let urlString = entity.url,
             let url = URL(string: urlString) {
            let localURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            if let attrs = try? fileManager.attributesOfItem(atPath: localURL.path),
               let size = attrs[.size] as? Int64 {
              totalBytes += size
            }
          }
        }

        // Get play count from AppMetrics
        let metricsRequest = NSFetchRequest<NSManagedObject>(entityName: "AppMetrics")
        metricsRequest.fetchLimit = 1
        let metricsResults = try context.fetch(metricsRequest)
        let playCount = metricsResults.first?.value(forKey: "playCount") as? Int64 ?? 0

        print("📊 Metrics: \(downloadCount) downloads, \(totalBytes) bytes, \(playCount) plays")
        return FileMetrics(
          downloadCount: downloadCount,
          totalStorageBytes: totalBytes,
          playCount: Int(playCount)
        )
      }
    },
    markFileDownloaded: { fileId in
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

      try await context.perform {
        let request = FileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "fileId == %@", fileId)
        request.fetchLimit = 1
        guard let entity = try context.fetch(request).first else {
          print("📊 File not found for marking downloaded: \(fileId)")
          return
        }
        entity.isDownloaded = true
        try context.save()
        print("📊 Marked file as downloaded: \(fileId)")
      }
    },
    incrementPlayCount: {
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

      try await context.perform {
        let request = NSFetchRequest<NSManagedObject>(entityName: "AppMetrics")
        request.fetchLimit = 1
        let results = try context.fetch(request)

        let metrics: NSManagedObject
        if let existing = results.first {
          metrics = existing
        } else {
          // Create singleton AppMetrics if doesn't exist
          let entity = NSEntityDescription.entity(forEntityName: "AppMetrics", in: context)!
          metrics = NSManagedObject(entity: entity, insertInto: context)
          metrics.setValue(Int64(0), forKey: "playCount")
        }

        let currentCount = metrics.value(forKey: "playCount") as? Int64 ?? 0
        metrics.setValue(currentCount + 1, forKey: "playCount")
        try context.save()
        print("📊 Incremented play count to \(currentCount + 1)")
      }
    },
    resetMetrics: {
      let context = PersistenceController.shared.container.newBackgroundContext()
      context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

      try await context.perform {
        // Reset isDownloaded on all FileEntity records
        let fileRequest = FileEntity.fetchRequest()
        let files = try context.fetch(fileRequest)
        for file in files {
          file.isDownloaded = false
        }

        // Reset play count in AppMetrics
        let metricsRequest = NSFetchRequest<NSManagedObject>(entityName: "AppMetrics")
        let metricsResults = try context.fetch(metricsRequest)
        if let metrics = metricsResults.first {
          metrics.setValue(Int64(0), forKey: "playCount")
        }

        try context.save()
        print("📊 Reset all metrics")
      }
    }
  )
}

// MARK: - Test/Preview implementation
extension CoreDataClient {
  static let testValue = CoreDataClient(
    getFiles: { [] },
    getFile: { _ in nil },
    cacheFiles: { _ in },
    cacheFile: { _ in },
    updateFileUrl: { _, _ in },
    updateFileStatus: { _, _ in },
    saveContext: { },
    truncateFiles: { },
    deleteFile: { _ in },
    getMetrics: { .zero },
    markFileDownloaded: { _ in },
    incrementPlayCount: { },
    resetMetrics: { }
  )
}
