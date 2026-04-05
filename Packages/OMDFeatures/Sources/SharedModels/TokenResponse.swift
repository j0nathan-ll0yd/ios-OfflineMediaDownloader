import Foundation

public struct TokenResponse: Codable, Sendable {
  public var token: String
  public var expiresAt: String? // ISO 8601 timestamp (e.g., "2026-02-18T16:14:58.812Z")
  public var sessionId: String?
  public var userId: String?

  /// Returns expiration date parsed from ISO 8601 string
  public var expirationDate: Date? {
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

  public init(token: String, expiresAt: String? = nil, sessionId: String? = nil, userId: String? = nil) {
    self.token = token
    self.expiresAt = expiresAt
    self.sessionId = sessionId
    self.userId = userId
  }
}
