import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var status: DownloadActivityStatus
    var progressPercent: Int
    var errorMessage: String?
  }

  var fileId: String
  var title: String
  var authorName: String?
}

enum DownloadActivityStatus: String, Codable {
  case queued = "Queued"
  case downloading = "Downloading"
  case downloaded = "Downloaded"
  case failed = "Failed"
}
