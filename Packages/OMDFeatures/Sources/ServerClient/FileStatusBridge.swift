import SharedModels
import APIClient

/// Bridge between generated API FileStatus and domain FileStatus
extension FileStatus {
  /// Initialize from generated API type
  public init(from apiStatus: APIFileStatus) {
    switch apiStatus {
    case .Queued: self = .queued
    case .Downloading: self = .downloading
    case .Downloaded: self = .downloaded
    case .Failed: self = .failed
    }
  }
}
