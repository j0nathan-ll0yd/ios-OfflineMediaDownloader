import ComposableArchitecture
import UIKit

/// Client for caching thumbnail images with two-tier cache (memory + disk)
@DependencyClient
public struct ThumbnailCacheClient: Sendable {
  /// Get thumbnail for a file, fetching from network if not cached
  public var getThumbnail: @Sendable (_ fileId: String, _ url: URL) async -> UIImage?
  /// Check if thumbnail exists in cache (memory or disk)
  public var hasCachedThumbnail: @Sendable (_ fileId: String) async -> Bool = { _ in false }
  /// Delete cached thumbnail for a file
  public var deleteThumbnail: @Sendable (_ fileId: String) async -> Void
  /// Clear all cached thumbnails
  public var clearCache: @Sendable () async -> Void
  /// Pre-fetch and cache thumbnails in background (fire-and-forget from reducers)
  public var prefetchThumbnails: @Sendable (_ thumbnails: [(fileId: String, url: URL)]) async -> Void
}

public extension DependencyValues {
  var thumbnailCacheClient: ThumbnailCacheClient {
    get { self[ThumbnailCacheClient.self] }
    set { self[ThumbnailCacheClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension ThumbnailCacheClient: DependencyKey {
  public static let liveValue = ThumbnailCacheClient(
    getThumbnail: { fileId, url in
      await ThumbnailCacheStorage.shared.getImage(fileId: fileId, url: url)
    },
    hasCachedThumbnail: { fileId in
      await ThumbnailCacheStorage.shared.hasCached(fileId: fileId)
    },
    deleteThumbnail: { fileId in
      await ThumbnailCacheStorage.shared.delete(fileId: fileId)
    },
    clearCache: {
      await ThumbnailCacheStorage.shared.clearAll()
    },
    prefetchThumbnails: { thumbnails in
      await ThumbnailCacheStorage.shared.prefetch(thumbnails: thumbnails)
    }
  )
}

// MARK: - Test Implementation

public extension ThumbnailCacheClient {
  static let testValue = ThumbnailCacheClient(
    getThumbnail: { _, _ in nil },
    hasCachedThumbnail: { _ in false },
    deleteThumbnail: { _ in },
    clearCache: {},
    prefetchThumbnails: { _ in }
  )

  static let previewValue = ThumbnailCacheClient(
    getThumbnail: { _, _ in nil },
    hasCachedThumbnail: { _ in false },
    deleteThumbnail: { _ in },
    clearCache: {},
    prefetchThumbnails: { _ in }
  )
}

// MARK: - Two-Tier Cache Storage Actor

private actor ThumbnailCacheStorage {
  static let shared = ThumbnailCacheStorage()

  // SAFETY: NSCache is thread-safe internally; actor isolation provides additional safety for access patterns
  private let memoryCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 100
    cache.totalCostLimit = 50 * 1024 * 1024 // 50MB decoded images
    return cache
  }()

  private var inflightTasks: [String: Task<UIImage?, Never>] = [:]

  init() {
    Self.cleanupOldDirectory()
  }

  // MARK: - Public API

  func getImage(fileId: String, url: URL) async -> UIImage? {
    // Tier 1: Memory cache (instant)
    if let cached = memoryCache.object(forKey: fileId as NSString) {
      return cached
    }

    // Deduplicate in-flight requests
    if let existingTask = inflightTasks[fileId] {
      return await existingTask.value
    }

    // Tier 2: Disk cache
    if let diskImage = loadFromDisk(fileId: fileId) {
      memoryCache.setObject(diskImage, forKey: fileId as NSString)
      return diskImage
    }

    // Tier 3: Network fetch with deduplication
    let task = Task<UIImage?, Never> {
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data)
        else { return nil }

        saveToDisk(fileId: fileId, image: image)
        memoryCache.setObject(image, forKey: fileId as NSString)
        return image
      } catch {
        return nil
      }
    }

    inflightTasks[fileId] = task
    let result = await task.value
    inflightTasks[fileId] = nil
    return result
  }

  func hasCached(fileId: String) -> Bool {
    if memoryCache.object(forKey: fileId as NSString) != nil { return true }
    return diskFileExists(fileId: fileId)
  }

  func delete(fileId: String) {
    memoryCache.removeObject(forKey: fileId as NSString)
    deleteDiskFile(fileId: fileId)
  }

  func clearAll() {
    memoryCache.removeAllObjects()
    clearDiskCache()
  }

  func prefetch(thumbnails: [(fileId: String, url: URL)]) async {
    await withTaskGroup(of: Void.self) { group in
      for (fileId, url) in thumbnails {
        group.addTask {
          _ = await self.getImage(fileId: fileId, url: url)
        }
      }
    }
  }

  // MARK: - Disk I/O (Library/Caches/thumbnails/)

  private func cacheDirectory() -> URL? {
    guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let dir = cachesDir.appendingPathComponent("thumbnails", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private func loadFromDisk(fileId: String) -> UIImage? {
    guard let dir = cacheDirectory() else { return nil }
    let path = dir.appendingPathComponent("\(fileId).jpg")
    guard let data = try? Data(contentsOf: path) else { return nil }
    return UIImage(data: data)
  }

  private func saveToDisk(fileId: String, image: UIImage) {
    guard let dir = cacheDirectory() else { return }
    let path = dir.appendingPathComponent("\(fileId).jpg")
    if let jpegData = image.jpegData(compressionQuality: 0.8) {
      try? jpegData.write(to: path)
    }
  }

  private func diskFileExists(fileId: String) -> Bool {
    guard let dir = cacheDirectory() else { return false }
    let path = dir.appendingPathComponent("\(fileId).jpg")
    return FileManager.default.fileExists(atPath: path.path)
  }

  private func deleteDiskFile(fileId: String) {
    guard let dir = cacheDirectory() else { return }
    let path = dir.appendingPathComponent("\(fileId).jpg")
    try? FileManager.default.removeItem(at: path)
  }

  private func clearDiskCache() {
    guard let dir = cacheDirectory() else { return }
    try? FileManager.default.removeItem(at: dir)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  // MARK: - Old Directory Cleanup (Documents/thumbnails/ -> deleted)

  private static func cleanupOldDirectory() {
    let fileManager = FileManager.default
    guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return }

    let oldDir = docsDir.appendingPathComponent("thumbnails", isDirectory: true)
    guard fileManager.fileExists(atPath: oldDir.path) else { return }
    try? fileManager.removeItem(at: oldDir)
  }
}
