import LifegamesComponents
import LifegamesComponentsCore
import LifegamesTokens
import SwiftUI

// MARK: - DirectionStyle

public struct DirectionStyle: Sendable {
  let accent: Color
  let cornerRadius: CGFloat
  let cardPadding: CGFloat
  let usesCard: Bool
  let monospacedNumerics: Bool
  let thumbnailSize: CGSize

  public static let neonConsole = DirectionStyle(
    accent: LGColor.accentBlue,
    cornerRadius: 20,
    cardPadding: Spacing.s450,
    usesCard: true,
    monospacedNumerics: true,
    thumbnailSize: CGSize(width: 120, height: 68)
  )
}

// MARK: - MediaThumbnailView

public struct MediaThumbnailView: View {
  let thumbnailSystemImage: String
  let duration: String
  let style: DirectionStyle

  public init(thumbnailSystemImage: String, duration: String, style: DirectionStyle) {
    self.thumbnailSystemImage = thumbnailSystemImage
    self.duration = duration
    self.style = style
  }

  public var body: some View {
    ZStack(alignment: .bottomTrailing) {
      RoundedRectangle(cornerRadius: style.cornerRadius == 0 ? 0 : 8)
        .fill(LGColor.surfaceRaised)
        .overlay(
          Image(systemName: thumbnailSystemImage)
            .font(.system(size: style.thumbnailSize.width == .infinity ? 48 : 24))
            .foregroundStyle(style.accent.opacity(0.7))
        )
        .frame(
          width: style.thumbnailSize.width == .infinity ? nil : style.thumbnailSize.width,
          height: style.thumbnailSize.height
        )

      DurationBadgeView(duration: duration, style: style)
        .padding(4)
    }
  }
}

// MARK: - DurationBadgeView

public struct DurationBadgeView: View {
  let duration: String
  let style: DirectionStyle

  public init(duration: String, style: DirectionStyle) {
    self.duration = duration
    self.style = style
  }

  public var body: some View {
    Text(duration)
      .font(style.monospacedNumerics ? OMDFont.mono(10) : OMDFont.medium(10))
      .foregroundStyle(LGColor.textTitle)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.black.opacity(0.72))
      .clipShape(Capsule())
  }
}

// MARK: - DownloadProgressView

public struct DownloadProgressView: View {
  let state: OMDDownloadState
  let style: DirectionStyle

  public init(state: OMDDownloadState, style: DirectionStyle) {
    self.state = state
    self.style = style
  }

  public var body: some View {
    switch state {
    case .downloaded:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(style.accent)
        .font(.system(size: iconSize))

    case let .downloading(progress):
      ZStack {
        Circle()
          .stroke(style.accent.opacity(0.2), lineWidth: lineWidth)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(style.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .shadow(color: style.monospacedNumerics ? style.accent.opacity(0.5) : .clear, radius: 4)
      }
      .frame(width: ringSize, height: ringSize)
      .accessibilityLabel("Downloading")
      .accessibilityValue("\(Int(progress * 100)) percent")

    case .queued:
      Image(systemName: "clock.fill")
        .foregroundStyle(LGColor.textSubtle)
        .font(.system(size: iconSize))

    case .none:
      Image(systemName: "arrow.down.circle")
        .foregroundStyle(LGColor.textSubtle)
        .font(.system(size: iconSize))
    }
  }

  private var ringSize: CGFloat {
    style.thumbnailSize.width == .infinity ? 24 : (style.thumbnailSize.width < 80 ? 16 : 24)
  }

  private var lineWidth: CGFloat {
    style.thumbnailSize.width < 80 ? 2 : 3
  }

  private var iconSize: CGFloat {
    style.thumbnailSize.width == .infinity ? 20 : (style.thumbnailSize.width < 80 ? 14 : 18)
  }
}

// MARK: - FileRow

// A media row: thumbnail-left, title, author, and an icon-based meta line
// (size / views; duration lives on the thumbnail badge). Colors are kept
// consistent across every row — a single accent for the author and the card
// edge — so the list reads calmly rather than as a rainbow.

public struct FileRow: View {
  let title: String
  let author: String
  let fileSize: String
  let viewCount: Int
  let duration: String
  let thumbnailSystemImage: String
  let state: OMDDownloadState

  public init(
    title: String,
    author: String,
    fileSize: String,
    viewCount: Int,
    duration: String,
    thumbnailSystemImage: String,
    state: OMDDownloadState
  ) {
    self.title = title
    self.author = author
    self.fileSize = fileSize
    self.viewCount = viewCount
    self.duration = duration
    self.thumbnailSystemImage = thumbnailSystemImage
    self.state = state
  }

  public var body: some View {
    HStack(alignment: .top, spacing: Spacing.s300) {
      MediaThumbnailView(
        thumbnailSystemImage: thumbnailSystemImage,
        duration: duration,
        style: .neonConsole
      )

      VStack(alignment: .leading, spacing: Spacing.s150) {
        Text(title)
          .font(OMDFont.semibold(14))
          .foregroundStyle(LGColor.textTitle)
          .lineLimit(2)
          .truncationMode(.tail)

        HStack(spacing: Spacing.s100) {
          Image(systemName: "person.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(LGColor.accentCyan)
          Text(author)
            .font(OMDFont.medium(12))
            .foregroundStyle(LGColor.accentCyan)
            .lineLimit(1)
        }

        // Duration lives on the thumbnail badge; the meta line carries
        // size + views so neither truncates in the row's text column.
        HStack(spacing: Spacing.s300) {
          metaItem(icon: "arrow.down.doc.fill", text: fileSize)
          metaItem(icon: "eye.fill", text: MetadataFormatters.formatViewCount(viewCount))
        }
      }

      Spacer(minLength: Spacing.s200)

      DownloadProgressView(state: state, style: .neonConsole)
    }
    .neonCard(accent: OMDPalette.primary)
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

// MARK: - ActiveDownloadBannerView

public struct ActiveDownloadBannerView: View {
  let title: String
  let progress: Double
  let style: DirectionStyle

  public init(title: String, progress: Double, style: DirectionStyle) {
    self.title = title
    self.progress = progress
    self.style = style
  }

  public var body: some View {
    HStack(spacing: Spacing.s300) {
      ZStack {
        Circle()
          .stroke(style.accent.opacity(0.2), lineWidth: 2)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(style.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .shadow(color: style.monospacedNumerics ? style.accent.opacity(0.6) : .clear, radius: 3)
      }
      .frame(width: 22, height: 22)
      .accessibilityLabel("Downloading")
      .accessibilityValue("\(Int(progress * 100)) percent")

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(OMDFont.medium(12))
          .foregroundStyle(LGColor.textPrimary)
          .lineLimit(1)

        Text(
          style.monospacedNumerics
            ? String(format: "%.0f%%", progress * 100)
            : "Downloading..."
        )
        .font(style.monospacedNumerics ? OMDFont.mono(10) : OMDFont.regular(10))
        .foregroundStyle(style.accent)
      }

      Spacer()

      Button {} label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 18))
          .foregroundStyle(LGColor.textSubtle)
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(.rect)
      .accessibilityLabel("Cancel download")
    }
    .padding(.horizontal, Spacing.s400)
    .padding(.vertical, Spacing.s200)
    .background(
      style.usesCard
        ? (style.monospacedNumerics
          ? AnyShapeStyle(.ultraThinMaterial)
          : AnyShapeStyle(LGColor.surfaceRaised))
        : AnyShapeStyle(LGColor.surfaceRaised)
    )
    .overlay(alignment: .top) {
      Rectangle()
        .fill(LGColor.borderSubtle)
        .frame(height: 0.5)
    }
  }
}

// MARK: - Previews

#Preview("OMD Media Components — Neon Console") {
  ScrollView {
    VStack(spacing: Spacing.s400) {
      MediaThumbnailView(
        thumbnailSystemImage: "film.stack",
        duration: "1:42:18",
        style: .neonConsole
      )
      .frame(maxWidth: .infinity)

      FileRow(
        title: "SwiftUI State Management Deep Dive",
        author: "Point-Free",
        fileSize: "1.2 GB",
        viewCount: 142_300,
        duration: "1:42:18",
        thumbnailSystemImage: "film.stack",
        state: .downloaded
      )

      FileRow(
        title: "The Composable Architecture in Practice",
        author: "Brandon Williams",
        fileSize: "876 MB",
        viewCount: 89500,
        duration: "58:44",
        thumbnailSystemImage: "play.rectangle.fill",
        state: .downloading(progress: 0.62)
      )

      ActiveDownloadBannerView(
        title: "The Composable Architecture in Practice",
        progress: 0.62,
        style: .neonConsole
      )
    }
    .padding(Spacing.s400)
  }
  .background(LGColor.surfaceBase)
  .preferredColorScheme(.dark)
}
