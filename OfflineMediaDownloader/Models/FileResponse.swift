import SwiftUI

struct ErrorDetail: Decodable {
  var code: String
  var message: String
}

struct FileResponse: Decodable {
  var body: FileList?
  var error: ErrorDetail?
  var requestId: String
}
