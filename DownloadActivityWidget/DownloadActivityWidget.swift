import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Activity Attributes

struct DownloadActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var status: DownloadActivityStatus
    var progressPercent: Int
    var errorMessage: String?
  }

  var fileId: String
  var title: String
  var authorName: String?
}

enum DownloadActivityStatus: String, Codable {
  case queued = "Queued"
  case downloading = "Downloading"
  case downloaded = "Downloaded"
  case failed = "Failed"
}

// MARK: - Widget

@main
struct DownloadActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
      // Lock Screen / Banner UI
      LockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded UI
        DynamicIslandExpandedRegion(.leading) {
          statusIcon(for: context.state.status)
            .font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.progressPercent)%")
            .font(.title2)
            .fontWeight(.semibold)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.title)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 8) {
            ProgressView(value: Double(context.state.progressPercent), total: 100)
              .tint(progressColor(for: context.state.status))

            if let author = context.attributes.authorName {
              Text(author)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let error = context.state.errorMessage {
              Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
            }
          }
        }
      } compactLeading: {
        statusIcon(for: context.state.status)
          .font(.caption)
      } compactTrailing: {
        Text("\(context.state.progressPercent)%")
          .font(.caption)
          .fontWeight(.semibold)
      } minimal: {
        statusIcon(for: context.state.status)
          .font(.caption)
      }
    }
  }

  @ViewBuilder
  private func statusIcon(for status: DownloadActivityStatus) -> some View {
    switch status {
    case .queued:
      Image(systemName: "clock.fill")
        .foregroundStyle(.orange)
    case .downloading:
      Image(systemName: "arrow.down.circle.fill")
        .foregroundStyle(.blue)
    case .downloaded:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .failed:
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
    }
  }

  private func progressColor(for status: DownloadActivityStatus) -> Color {
    switch status {
    case .queued: return .orange
    case .downloading: return .blue
    case .downloaded: return .green
    case .failed: return .red
    }
  }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
  let context: ActivityViewContext<DownloadActivityAttributes>

  var body: some View {
    HStack(spacing: 12) {
      statusIcon
        .font(.title)

      VStack(alignment: .leading, spacing: 4) {
        Text(context.attributes.title)
          .font(.headline)
          .lineLimit(1)

        if let author = context.attributes.authorName {
          Text(author)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        if context.state.status == .failed, let error = context.state.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(1)
        }
      }

      Spacer()

      if context.state.status == .downloading {
        VStack {
          Text("\(context.state.progressPercent)%")
            .font(.headline)
            .fontWeight(.semibold)
          ProgressView(value: Double(context.state.progressPercent), total: 100)
            .frame(width: 60)
        }
      } else {
        statusBadge
      }
    }
    .padding()
    .background(.ultraThinMaterial)
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch context.state.status {
    case .queued:
      Image(systemName: "clock.fill")
        .foregroundStyle(.orange)
    case .downloading:
      Image(systemName: "arrow.down.circle.fill")
        .foregroundStyle(.blue)
    case .downloaded:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .failed:
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    Text(context.state.status.rawValue)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(badgeColor.opacity(0.2))
      .foregroundStyle(badgeColor)
      .clipShape(Capsule())
  }

  private var badgeColor: Color {
    switch context.state.status {
    case .queued: return .orange
    case .downloading: return .blue
    case .downloaded: return .green
    case .failed: return .red
    }
  }
}
