import Foundation

struct TokenResponse: Codable, Sendable {
  var token: String
  var expiresAt: String?  // ISO 8601 timestamp (e.g., "2026-02-18T16:14:58.812Z")
  var sessionId: String?
  var userId: String?

  /// Returns expiration date parsed from ISO 8601 string
  var expirationDate: Date? {
    guard let dateString = expiresAt else { return nil }
    // Try parsing with fractional seconds first (server format: "2026-02-18T16:14:58.812Z")
    let formatterWithFractional = ISO8601DateFormatter()
    formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatterWithFractional.date(from: dateString) {
      return date
    }
    // Fallback to standard format without fractional seconds
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
  }
}
