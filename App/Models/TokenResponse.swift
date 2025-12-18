import Foundation

struct TokenResponse: Decodable {
  let token: String
  let expiresAt: Double?
  let sessionId: String?
  let userId: String?
}
