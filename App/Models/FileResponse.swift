import SwiftUI

struct ErrorDetail: Codable, Sendable {
  var message: String
  var code: String?
}

struct FileResponse: Codable, Sendable {
  var body: FileList?
  var error: ErrorDetail?
  var requestId: String
}
