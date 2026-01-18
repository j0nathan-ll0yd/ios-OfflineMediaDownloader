import Foundation

struct TokenResponse: Codable, Sendable {
  var token: String
  var expiresAt: Double?  // Unix timestamp from login/register endpoints
  var expiresAtString: String?  // ISO 8601 from refresh endpoint
  var sessionId: String?
  var userId: String?

  /// Returns expiration date from either format
  var expirationDate: Date? {
    if let timestamp = expiresAt {
      return Date(timeIntervalSince1970: timestamp)
    }
    if let dateString = expiresAtString {
      return ISO8601DateFormatter().date(from: dateString)
    }
    return nil
  }
}
