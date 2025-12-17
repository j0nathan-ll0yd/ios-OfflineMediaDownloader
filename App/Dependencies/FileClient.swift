import ComposableArchitecture
import Foundation

@DependencyClient
struct FileClient {
  var documentsDirectory: @Sendable () -> URL = {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  }
  var filePath: @Sendable (_ url: URL) -> URL = { url in
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return documentsPath.appendingPathComponent(url.lastPathComponent)
  }
  var fileExists: @Sendable (_ url: URL) -> Bool = { _ in false }
  var deleteFile: @Sendable (_ url: URL) async throws -> Void
  var moveFile: @Sendable (_ from: URL, _ to: URL) throws -> Void
}

extension DependencyValues {
  var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

enum FileClientError: Error {
  case deletionFailed(String)
  case moveFailed(String)
}

// MARK: - Live API implementation
extension FileClient: DependencyKey {
  static let liveValue = FileClient(
    documentsDirectory: {
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    },
    filePath: { url in
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      return documentsPath.appendingPathComponent(url.lastPathComponent)
    },
    fileExists: { url in
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      let fileURL = documentsPath.appendingPathComponent(url.lastPathComponent)
      return FileManager.default.fileExists(atPath: fileURL.path)
    },
    deleteFile: { url in
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      let fileURL = documentsPath.appendingPathComponent(url.lastPathComponent)
      if FileManager.default.fileExists(atPath: fileURL.path) {
        do {
          try FileManager.default.removeItem(at: fileURL)
        } catch {
          throw FileClientError.deletionFailed("Error deleting file \(fileURL): \(error)")
        }
      }
    },
    moveFile: { from, to in
      // Remove existing file if present
      if FileManager.default.fileExists(atPath: to.path) {
        try FileManager.default.removeItem(at: to)
      }
      try FileManager.default.moveItem(at: from, to: to)
    }
  )
}
