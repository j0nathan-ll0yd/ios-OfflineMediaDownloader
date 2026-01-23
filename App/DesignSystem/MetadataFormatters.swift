import Foundation

/// Formats metadata values for display
public enum MetadataFormatters {
  public static func formatDuration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
      return String(format: "%d:%02d", minutes, secs)
    }
  }

  public static func formatViewCount(_ count: Int) -> String {
    switch count {
    case 0..<1_000:
      return "\(count) views"
    case 1_000..<1_000_000:
      return String(format: "%.1fK views", Double(count) / 1_000)
    default:
      return String(format: "%.1fM views", Double(count) / 1_000_000)
    }
  }

  public static func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}
