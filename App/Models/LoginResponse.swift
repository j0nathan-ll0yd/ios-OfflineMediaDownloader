import Foundation

struct LoginResponse: Decodable {
  let body: TokenResponse?
  let error: ErrorDetail?
  let requestId: String
}
