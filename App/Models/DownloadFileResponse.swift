import SwiftUI

struct DownloadFileResponseDetail: Decodable {
  var status: String
}

struct DownloadFileResponse: Decodable {
  var body: DownloadFileResponseDetail?
  var error: ErrorDetail?
  var requestId: String
}
