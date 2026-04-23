import ComposableArchitecture
import SwiftUI

/// A floating banner that displays active download progress.
/// Shows above the tab bar when downloads are in progress.
struct ActiveDownloadsBanner: View {
  let store: StoreOf<ActiveDownloadsFeature>

  private let theme = DarkProfessionalTheme()

  var body: some View {
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

        // Progress bar (shown for serverDownloading and downloading)
        if case .serverDownloading = download.status {
          progressBarView
        } else if case .downloading = download.status {
          progressBarView
        }
      }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch download.status {
    case .queued:
      Image(systemName: "clock.fill")
        .font(.title3)
        .foregroundStyle(theme.textSecondary)

    case .serverDownloading:
      Image(systemName: "cloud.fill")
        .font(.title3)
        .foregroundStyle(theme.primaryColor)
        .symbolEffect(.pulse, options: .repeating)

    case .downloading:
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
    case .queued:
      "Queued"
    case .serverDownloading:
      download.progress > 0 ? "Server \(download.progress)%" : "Server..."
    case .downloading:
      "\(download.progress)%"
    case .completed:
      "Done"
    case let .failed(error):
      error.prefix(20) + (error.count > 20 ? "..." : "")
    }
  }

  private var statusColor: Color {
    switch download.status {
    case .queued:
      theme.textSecondary
    case .serverDownloading:
      theme.primaryColor
    case .downloading:
      theme.textSecondary
    case .completed:
      theme.successColor
    case .failed:
      theme.errorColor
    }
  }

  private var progressBarView: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2)
          .fill(theme.textSecondary.opacity(0.2))
          .frame(height: 4)

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

#Preview("Active Downloads") {
  VStack {
    Spacer()
    ActiveDownloadsBanner(
      store: Store(
        initialState: ActiveDownloadsFeature.State(
          activeDownloads: [
            .init(fileId: "1", title: "Queued Video.mp4", progress: 0, status: .queued, isBackgroundInitiated: true),
            .init(fileId: "2", title: "Server Download.mp4", progress: 50, status: .serverDownloading, isBackgroundInitiated: true),
            .init(fileId: "3", title: "My Video File.mp4", progress: 45, status: .downloading, isBackgroundInitiated: true),
            .init(fileId: "4", title: "Completed File.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
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
