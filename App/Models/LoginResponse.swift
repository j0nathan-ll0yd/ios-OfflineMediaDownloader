import Foundation

struct LoginResponse: Codable {
  var body: TokenResponse?
  var error: ErrorDetail?
  var requestId: String
}
