import SwiftUI

/// Stat item for detail view
public struct StatItem: View {
  let label: String
  let value: String

  public init(label: String, value: String) {
    self.label = label
    self.value = value
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.callout)
        .fontWeight(.medium)
        .foregroundStyle(.white)
    }
  }
}
