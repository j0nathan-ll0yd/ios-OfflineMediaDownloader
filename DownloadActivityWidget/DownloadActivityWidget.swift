import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DownloadActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
      // Lock screen / banner UI
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(context.attributes.title)
            .font(.headline)
          Spacer()
          Text(context.state.status.rawValue)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let authorName = context.attributes.authorName {
          Text(authorName)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        if context.state.status == .downloading {
          ProgressView(value: Double(context.state.progressPercent), total: 100)
            .tint(.blue)
          Text("\(context.state.progressPercent)%")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let errorMessage = context.state.errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
      .padding()
      .activityBackgroundTint(.black.opacity(0.2))
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded UI
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading) {
            Text(context.attributes.title)
              .font(.headline)
            if let authorName = context.attributes.authorName {
              Text(authorName)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          VStack {
            Text(context.state.status.rawValue)
              .font(.caption)
            if context.state.status == .downloading {
              Text("\(context.state.progressPercent)%")
                .font(.title2)
                .bold()
            }
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          if context.state.status == .downloading {
            ProgressView(value: Double(context.state.progressPercent), total: 100)
              .tint(.blue)
          }
          if let errorMessage = context.state.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }
      } compactLeading: {
        // Compact leading UI (left side of notch)
        Image(systemName: "arrow.down.circle.fill")
          .foregroundStyle(.blue)
      } compactTrailing: {
        // Compact trailing UI (right side of notch)
        if context.state.status == .downloading {
          Text("\(context.state.progressPercent)%")
            .font(.caption2)
        } else {
          Image(systemName: statusIcon(for: context.state.status))
        }
      } minimal: {
        // Minimal UI (when multiple activities)
        Image(systemName: "arrow.down.circle.fill")
      }
    }
  }

  private func statusIcon(for status: DownloadActivityStatus) -> String {
    switch status {
    case .queued:
      return "clock"
    case .downloading:
      return "arrow.down.circle"
    case .downloaded:
      return "checkmark.circle.fill"
    case .failed:
      return "exclamationmark.circle.fill"
    }
  }
}
