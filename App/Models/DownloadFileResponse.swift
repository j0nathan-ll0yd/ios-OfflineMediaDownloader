import SwiftUI

struct DownloadFileResponseDetail: Codable {
  var status: String
}

struct DownloadFileResponse: Codable {
  var body: DownloadFileResponseDetail?
  var error: ErrorDetail?
  var requestId: String
}
