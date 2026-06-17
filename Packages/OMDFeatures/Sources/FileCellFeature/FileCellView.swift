import ComposableArchitecture
import DesignSystem
import LifegamesComponentsCore
import LifegamesTokens
import SwiftUI
import ThumbnailCacheClient

// MARK: - FileCellView

public struct FileCellView: View {
  @Bindable var store: StoreOf<FileCellFeature>

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
    HStack(alignment: .top, spacing: Spacing.s300) {
      // Thumbnail with duration badge — real artwork, neon-card styling
      ZStack(alignment: .bottomTrailing) {
        ThumbnailImage(fileId: store.file.fileId, url: thumbnailURL, size: thumbnailSize)
          .clipShape(RoundedRectangle(cornerRadius: 8))

        if let duration = store.file.duration {
          DurationBadge(seconds: duration)
            .padding(4)
        }
      }
      .frame(width: thumbnailSize.width, height: thumbnailSize.height)
      .overlay { playOverlay }
      .contentShape(Rectangle())
      .onTapGesture {
        thumbnailAction?()
      }

      // File info
      VStack(alignment: .leading, spacing: Spacing.s150) {
        Text(store.file.title ?? store.file.key)
          .font(OMDFont.semibold(14))
          .foregroundStyle(LGColor.textTitle)
          .lineLimit(2)
          .truncationMode(.tail)

        // Author with playback/identity accent (cyan)
        if let author = store.file.authorName {
          HStack(spacing: Spacing.s100) {
            Image(systemName: "person.circle.fill")
              .font(.system(size: 11))
              .foregroundStyle(OMDPalette.playback)
            Text(author)
              .font(OMDFont.medium(12))
              .foregroundStyle(OMDPalette.playback)
              .lineLimit(1)
          }
        }

        // Icon-based meta line: size + views (duration lives on the badge)
        HStack(spacing: Spacing.s300) {
          if let size = store.file.size, size > 0 {
            metaItem(icon: "arrow.down.doc.fill", text: formatFileSize(size))
          }
          if let viewCount = store.file.viewCount {
            metaItem(icon: "eye.fill", text: MetadataFormatters.formatViewCount(viewCount))
          }
        }
      }

      Spacer(minLength: Spacing.s200)

      statusIndicator
        .frame(maxHeight: .infinity, alignment: .center)
    }
    .neonCard(accent: OMDPalette.primary)
    .task {
      store.send(.onAppear)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  /// Play affordance over a downloaded thumbnail. The row's status itself lives
  /// on the trailing indicator, so the overlay only signals playability.
  @ViewBuilder
  private var playOverlay: some View {
    if store.isDownloaded {
      Image(systemName: "play.fill")
        .font(.system(size: 22))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 2)
    }
  }

  /// Trailing download-status indicator mirroring the design system's
  /// DownloadProgressView (check / ring / clock / arrow), plus OMD's pending
  /// and server-downloading states.
  @ViewBuilder
  private var statusIndicator: some View {
    if store.state.isPending {
      Image(systemName: "clock.fill")
        .font(.system(size: 18))
        .foregroundStyle(LGColor.textSubtle)
    } else if store.isServerDownloading {
      Image(systemName: "icloud.and.arrow.down")
        .font(.system(size: 18))
        .foregroundStyle(OMDPalette.playback)
    } else if store.isDownloading {
      ZStack {
        Circle()
          .stroke(OMDPalette.primary.opacity(0.2), lineWidth: 3)
        Circle()
          .trim(from: 0, to: store.downloadProgress)
          .stroke(OMDPalette.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .shadow(color: OMDPalette.primary.opacity(0.5), radius: 4)
      }
      .frame(width: 24, height: 24)
      .accessibilityLabel("Downloading")
      .accessibilityValue("\(Int(store.downloadProgress * 100)) percent")
    } else if store.isDownloaded {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 18))
        .foregroundStyle(OMDPalette.primary)
    } else {
      Image(systemName: "arrow.down.circle")
        .font(.system(size: 18))
        .foregroundStyle(LGColor.textSubtle)
    }
  }

  private func metaItem(icon: String, text: String) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon)
        .font(.system(size: 9))
      Text(text)
        .font(OMDFont.mono(11))
        .lineLimit(1)
    }
    .foregroundStyle(LGColor.textSubtle)
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
