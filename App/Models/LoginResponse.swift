import Foundation

struct LoginResponse: Codable, Sendable {
  var body: TokenResponse?
  var error: ErrorDetail?
  var requestId: String
}
