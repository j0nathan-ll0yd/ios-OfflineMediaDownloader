import Foundation

/// Shared date formatters for the application.
/// Using cached formatters improves performance by avoiding repeated formatter creation.
enum DateFormatters {
  /// Date formatter for YYYYMMDD format (API responses)
  static let yyyyMMdd: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  /// Date formatter for ISO date format (push notifications)
  static let iso: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  /// Parse a date string, trying YYYYMMDD first, then ISO format
  /// - Parameter dateString: The date string to parse
  /// - Returns: The parsed date, or nil if parsing failed
  static func parse(_ dateString: String) -> Date? {
    yyyyMMdd.date(from: dateString) ?? iso.date(from: dateString)
  }

  /// Format a date to YYYYMMDD string
  /// - Parameter date: The date to format
  /// - Returns: The formatted string
  static func format(_ date: Date) -> String {
    yyyyMMdd.string(from: date)
  }
}
