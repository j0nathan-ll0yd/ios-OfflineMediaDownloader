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
  var saveContext: @Sendable () async throws -> Void
  var truncateFiles: @Sendable () async throws -> Void
  var deleteFile: @Sendable (File) async throws -> Void
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
    saveContext: { },
    truncateFiles: { },
    deleteFile: { _ in }
  )
}
