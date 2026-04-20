import ComposableArchitecture
import DesignSystem
import SwiftUI
import ThumbnailCacheClient

// MARK: - FileCellView

public struct FileCellView: View {
  @Bindable var store: StoreOf<FileCellFeature>

  private let theme = DarkProfessionalTheme()
  private let thumbnailSize = CGSize(width: 120, height: 68)

  public init(store: StoreOf<FileCellFeature>) {
    self.store = store
  }

  /// Thumbnail action based on current state
  private var thumbnailAction: (() -> Void)? {
    // Pending files have no action
    if store.state.isPending { return nil }
    if store.isDownloading { return { store.send(.cancelDownloadButtonTapped) } }
    if store.isDownloaded { return { store.send(.playButtonTapped) } }
    return { store.send(.downloadButtonTapped) }
  }

  /// Parse thumbnailUrl string to URL
  private var thumbnailURL: URL? {
    guard let urlString = store.file.thumbnailUrl else { return nil }
    return URL(string: urlString)
  }

  public var body: some View {
    HStack(spacing: 14) {
      // Thumbnail with duration badge
      ZStack(alignment: .bottomTrailing) {
        ThumbnailImage(fileId: store.file.fileId, url: thumbnailURL, size: thumbnailSize)

        if let duration = store.file.duration {
          DurationBadge(seconds: duration)
            .padding(4)
        }
      }
      .frame(width: thumbnailSize.width, height: thumbnailSize.height)
      .overlay { stateOverlay }
      .contentShape(Rectangle())
      .onTapGesture {
        thumbnailAction?()
      }

      // File info
      VStack(alignment: .leading, spacing: 3) {
        Text(store.file.title ?? store.file.key)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.white)
          .lineLimit(2)

        // Author with accent color
        if let author = store.file.authorName {
          Text(author)
            .font(.caption)
            .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
        }

        // Views + Size
        HStack(spacing: 6) {
          if let viewCount = store.file.viewCount {
            Text(MetadataFormatters.formatViewCount(viewCount))
          }
          if store.file.viewCount != nil, store.file.size != nil {
            Text("•")
          }
          if store.file.size != nil {
            Text(formatFileSize(store.file.size))
          }
        }
        .font(.caption)
        .foregroundStyle(theme.textSecondary)

        statusText
      }

      Spacer()

      // Progress ring for downloading
      if store.isDownloading {
        glowingProgressRing
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(theme.surfaceColor)
    .overlay(
      Rectangle()
        .fill(DarkProfessionalTheme.divider)
        .frame(height: 0.5),
      alignment: .bottom
    )
    .task {
      store.send(.onAppear)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  @ViewBuilder
  private var stateOverlay: some View {
    if store.state.isPending {
      Image(systemName: "clock")
        .font(.system(size: 22))
        .foregroundStyle(theme.warningColor)
        .shadow(color: .black.opacity(0.5), radius: 2)
    } else if store.isServerDownloading {
      Image(systemName: "icloud.and.arrow.down")
        .font(.system(size: 22))
        .foregroundStyle(.cyan)
        .shadow(color: .black.opacity(0.5), radius: 2)
    } else if store.isDownloading {
      // Show mini progress in thumbnail during download
      ZStack {
        Circle()
          .stroke(theme.primaryColor.opacity(0.3), lineWidth: 2)
          .frame(width: 28, height: 28)

        Circle()
          .trim(from: 0, to: store.downloadProgress)
          .stroke(theme.primaryColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .frame(width: 28, height: 28)
          .rotationEffect(.degrees(-90))
      }
      .shadow(color: .black.opacity(0.5), radius: 2)
    } else if store.isDownloaded {
      Image(systemName: "play.fill")
        .font(.system(size: 22))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 2)
    }
    // No overlay for available (not downloaded) state - thumbnail speaks for itself
  }

  @ViewBuilder
  private var statusText: some View {
    if store.state.isPending {
      Text("Processing...")
        .font(.caption2)
        .foregroundStyle(theme.warningColor)
    } else if store.isServerDownloading {
      Text("Server downloading...")
        .font(.caption2)
        .foregroundStyle(.cyan)
    } else if store.isDownloading {
      Text("Downloading \(Int(store.downloadProgress * 100))%")
        .font(.caption2)
        .foregroundStyle(theme.primaryColor)
        .monospacedDigit()
    } else if store.isDownloaded {
      Text("Downloaded")
        .font(.caption2)
        .foregroundStyle(theme.successColor)
    }
  }

  private var glowingProgressRing: some View {
    ZStack {
      // Glow
      Circle()
        .fill(theme.primaryColor.opacity(0.2))
        .frame(width: 44, height: 44)
        .blur(radius: 8)

      // Track
      Circle()
        .stroke(theme.primaryColor.opacity(0.2), lineWidth: 3)
        .frame(width: 36, height: 36)

      // Progress
      Circle()
        .trim(from: 0, to: store.downloadProgress)
        .stroke(
          LinearGradient(
            colors: [theme.primaryColor, theme.accentColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .frame(width: 36, height: 36)
        .rotationEffect(.degrees(-90))

      Text("\(Int(store.downloadProgress * 100))")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .monospacedDigit()
    }
  }
}

/// Format bytes to human-readable string (e.g., "45 MB")
private func formatFileSize(_ bytes: Int?) -> String {
  guard let bytes, bytes > 0 else { return "" }
  let mb = Double(bytes) / 1_000_000
  if mb >= 1000 {
    return String(format: "%.1f GB", mb / 1000)
  }
  return String(format: "%.0f MB", mb)
}
