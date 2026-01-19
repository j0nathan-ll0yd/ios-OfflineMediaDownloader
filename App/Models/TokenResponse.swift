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
      // Server returns ISO 8601 with fractional seconds (e.g., "2026-02-18T16:14:58.812Z")
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return formatter.date(from: dateString)
    }
    return nil
  }
}
