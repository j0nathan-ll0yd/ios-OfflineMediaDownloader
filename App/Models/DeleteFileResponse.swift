import Foundation

struct DeleteFileResponseDetail: Codable {
  var deleted: Bool
  var fileRemoved: Bool
}

struct DeleteFileResponse: Codable {
  var body: DeleteFileResponseDetail?
  var error: ErrorDetail?
  var requestId: String
}
