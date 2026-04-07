import ActivityKit
import Foundation

public struct DownloadActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable, Sendable {
    public var status: DownloadActivityStatus
    public var progressPercent: Int
    public var errorMessage: String?
    public var title: String
    public var authorName: String?

    public init(status: DownloadActivityStatus, progressPercent: Int, errorMessage: String? = nil, title: String, authorName: String? = nil) {
      self.status = status
      self.progressPercent = progressPercent
      self.errorMessage = errorMessage
      self.title = title
      self.authorName = authorName
    }
  }

  public var fileId: String

  public init(fileId: String) {
    self.fileId = fileId
  }
}

public enum DownloadActivityStatus: String, Codable, Sendable {
  case queued = "Queued"
  case downloading = "Downloading"
  case downloaded = "Downloaded"
  case failed = "Failed"
}
