import SwiftUI

struct ErrorDetail: Codable {
  var message: String
  var code: String?
}

struct FileResponse: Decodable {
  var body: FileList?
  var error: ErrorDetail?
  var requestId: String
}
