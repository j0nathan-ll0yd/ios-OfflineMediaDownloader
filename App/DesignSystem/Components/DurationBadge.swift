import SwiftUI

/// Duration badge overlay for thumbnails
public struct DurationBadge: View {
  let seconds: Int

  public init(seconds: Int) {
    self.seconds = seconds
  }

  public var body: some View {
    Text(MetadataFormatters.formatDuration(seconds))
      .font(.caption2.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(.black.opacity(0.75))
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}
