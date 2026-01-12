import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var status: DownloadActivityStatus
    var progressPercent: Int
    var errorMessage: String?
    // Dynamic content that can be updated
    var title: String
    var authorName: String?
  }

  // Only truly static attributes here
  var fileId: String
}

enum DownloadActivityStatus: String, Codable {
  case queued = "Queued"
  case downloading = "Downloading"
  case downloaded = "Downloaded"
  case failed = "Failed"
}
