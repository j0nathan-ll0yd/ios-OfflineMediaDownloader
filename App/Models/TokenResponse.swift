import Foundation

struct TokenResponse: Codable, Sendable {
  var token: String
  var expiresAt: Double?
  var sessionId: String?
  var userId: String?
}
