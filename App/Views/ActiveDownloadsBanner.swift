import SwiftUI
import ComposableArchitecture

/// A floating banner that displays active download progress.
/// Shows above the tab bar when downloads are in progress.
struct ActiveDownloadsBanner: View {
  let store: StoreOf<ActiveDownloadsFeature>

  private let theme = DarkProfessionalTheme()

  var body: some View {
    WithPerceptionTracking {
      if store.hasVisibleDownloads {
        VStack(spacing: 0) {
          // Downloads list
          VStack(spacing: 8) {
            ForEach(store.activeDownloads) { download in
              DownloadRowView(download: download)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(theme.surfaceColor)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.activeDownloads.count)
      }
    }
  }
}

/// Individual download row showing progress
private struct DownloadRowView: View {
  let download: ActiveDownloadsFeature.ActiveDownload

  private let theme = DarkProfessionalTheme()

  var body: some View {
    HStack(spacing: 12) {
      // Status icon
      statusIcon
        .frame(width: 24, height: 24)

      // Title and progress bar
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(download.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)

          Spacer()

          // Background indicator
          if download.isBackgroundInitiated {
            Image(systemName: "arrow.down.app")
              .font(.caption)
              .foregroundStyle(theme.textSecondary)
          }

          // Progress percentage
          Text(progressText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(statusColor)
        }

        // Progress bar
        if case .downloading = download.status {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              // Background track
              RoundedRectangle(cornerRadius: 2)
                .fill(theme.textSecondary.opacity(0.2))
                .frame(height: 4)

              // Progress fill
              RoundedRectangle(cornerRadius: 2)
                .fill(
                  LinearGradient(
                    colors: [theme.primaryColor, theme.accentColor],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: geometry.size.width * CGFloat(download.progress) / 100, height: 4)
                .animation(.linear(duration: 0.2), value: download.progress)
            }
          }
          .frame(height: 4)
        }
      }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch download.status {
    case .downloading:
      // Animated downloading icon
      Image(systemName: "arrow.down.circle.fill")
        .font(.title3)
        .foregroundStyle(theme.primaryColor)
        .symbolEffect(.pulse, options: .repeating)

    case .completed:
      Image(systemName: "checkmark.circle.fill")
        .font(.title3)
        .foregroundStyle(theme.successColor)

    case .failed:
      Image(systemName: "exclamationmark.circle.fill")
        .font(.title3)
        .foregroundStyle(theme.errorColor)
    }
  }

  private var progressText: String {
    switch download.status {
    case .downloading:
      return "\(download.progress)%"
    case .completed:
      return "Done"
    case let .failed(error):
      return error.prefix(20) + (error.count > 20 ? "..." : "")
    }
  }

  private var statusColor: Color {
    switch download.status {
    case .downloading:
      return theme.textSecondary
    case .completed:
      return theme.successColor
    case .failed:
      return theme.errorColor
    }
  }
}

#Preview("Active Downloads") {
  VStack {
    Spacer()
    ActiveDownloadsBanner(
      store: Store(
        initialState: ActiveDownloadsFeature.State(
          activeDownloads: [
            .init(fileId: "1", title: "My Video File.mp4", progress: 45, status: .downloading, isBackgroundInitiated: true),
            .init(fileId: "2", title: "Another Download.mp4", progress: 78, status: .downloading, isBackgroundInitiated: false),
            .init(fileId: "3", title: "Completed File.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
          ]
        )
      ) {
        ActiveDownloadsFeature()
      }
    )
  }
  .background(Color(hex: "121212"))
  .preferredColorScheme(.dark)
}
