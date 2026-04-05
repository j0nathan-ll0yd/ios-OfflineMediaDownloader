import APIClient
import SharedModels

/// Bridge between generated API FileStatus and domain FileStatus
public extension FileStatus {
  /// Initialize from generated API type
  init(from apiStatus: APIFileStatus) {
    switch apiStatus {
    case .Queued: self = .queued
    case .Downloading: self = .downloading
    case .Downloaded: self = .downloaded
    case .Failed: self = .failed
    }
  }
}
