import ComposableArchitecture
import UIKit

/// Client for caching thumbnail images to disk
@DependencyClient
struct ThumbnailCacheClient: Sendable {
  /// Get thumbnail for a file, fetching from network if not cached
  var getThumbnail: @Sendable (_ fileId: String, _ url: URL) async -> UIImage?
  /// Check if thumbnail exists in cache
  var hasCachedThumbnail: @Sendable (_ fileId: String) -> Bool = { _ in false }
  /// Delete cached thumbnail for a file
  var deleteThumbnail: @Sendable (_ fileId: String) async -> Void
  /// Clear all cached thumbnails
  var clearCache: @Sendable () async -> Void
}

extension DependencyValues {
  var thumbnailCacheClient: ThumbnailCacheClient {
    get { self[ThumbnailCacheClient.self] }
    set { self[ThumbnailCacheClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension ThumbnailCacheClient: DependencyKey {
  static let liveValue = ThumbnailCacheClient(
    getThumbnail: { fileId, url in
      let fileManager = FileManager.default
      guard let cacheDir = thumbnailCacheDirectory() else { return nil }

      let cachedPath = cacheDir.appendingPathComponent("\(fileId).jpg")

      // Check if cached
      if fileManager.fileExists(atPath: cachedPath.path) {
        if let data = try? Data(contentsOf: cachedPath),
           let image = UIImage(data: data) {
          return image
        }
      }

      // Fetch from network
      do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
          return nil
        }

        // Save to cache (use JPEG for smaller file size)
        if let jpegData = image.jpegData(compressionQuality: 0.8) {
          try? jpegData.write(to: cachedPath)
        }

        return image
      } catch {
        return nil
      }
    },
    hasCachedThumbnail: { fileId in
      guard let cacheDir = thumbnailCacheDirectory() else { return false }
      let cachedPath = cacheDir.appendingPathComponent("\(fileId).jpg")
      return FileManager.default.fileExists(atPath: cachedPath.path)
    },
    deleteThumbnail: { fileId in
      guard let cacheDir = thumbnailCacheDirectory() else { return }
      let cachedPath = cacheDir.appendingPathComponent("\(fileId).jpg")
      try? FileManager.default.removeItem(at: cachedPath)
    },
    clearCache: {
      guard let cacheDir = thumbnailCacheDirectory() else { return }
      try? FileManager.default.removeItem(at: cacheDir)
      // Recreate empty directory
      try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
  )
}

// MARK: - Test Implementation

extension ThumbnailCacheClient {
  static let testValue = ThumbnailCacheClient(
    getThumbnail: { _, _ in nil },
    hasCachedThumbnail: { _ in false },
    deleteThumbnail: { _ in },
    clearCache: { }
  )

  static let previewValue = ThumbnailCacheClient(
    getThumbnail: { _, _ in nil },
    hasCachedThumbnail: { _ in false },
    deleteThumbnail: { _ in },
    clearCache: { }
  )
}

// MARK: - Helpers

private func thumbnailCacheDirectory() -> URL? {
  guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
    return nil
  }
  let cacheDir = documentsDir.appendingPathComponent("thumbnails", isDirectory: true)

  // Create directory if needed
  if !FileManager.default.fileExists(atPath: cacheDir.path) {
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
  }

  return cacheDir
}
