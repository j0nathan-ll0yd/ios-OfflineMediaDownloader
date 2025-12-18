import SwiftUI

struct DownloadFileResponseDetail: Codable, Sendable {
  var status: String
}

struct DownloadFileResponse: Codable, Sendable {
  var body: DownloadFileResponseDetail?
  var error: ErrorDetail?
  var requestId: String
}
