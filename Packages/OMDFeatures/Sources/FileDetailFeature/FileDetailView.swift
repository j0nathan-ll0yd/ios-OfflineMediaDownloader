import ComposableArchitecture
import DesignSystem
import LifegamesComponents
import LifegamesComponentsCore
import LifegamesTemplates
import LifegamesTokens
import SharedModels
import SwiftUI
import ThumbnailCacheClient

// MARK: - FileDetailView

public struct FileDetailView: View {
  @Bindable var store: StoreOf<FileDetailFeature>

  public init(store: StoreOf<FileDetailFeature>) {
    self.store = store
  }

  /// Parse thumbnailUrl string to URL
  private var thumbnailURL: URL? {
    guard let urlString = store.file.thumbnailUrl else { return nil }
    return URL(string: urlString)
  }

  public var body: some View {
    DetailTemplate(accent: OMDPalette.primary) {
      heroSlot
    } metadata: {
      metadataSlot
    } description: {
      descriptionSlot
    } actions: {
      actionsSlot
    }
    .background(LGColor.surfaceBase)
    .navigationTitle("")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if store.isDownloaded {
            Button {
              store.send(.shareButtonTapped)
            } label: {
              Image(systemName: "square.and.arrow.up")
                .foregroundStyle(OMDPalette.primary)
            }
            .accessibilityLabel("Share")
          }
        }
      }
      .task { store.send(.onAppear) }
      .alert($store.scope(state: \.alert, action: \.alert))
      .preferredColorScheme(.dark)
  }

  // MARK: - Hero Slot

  private var heroSlot: some View {
    ZStack(alignment: .bottomTrailing) {
      GeometryReader { geometry in
        let width = geometry.size.width
        ZStack {
          if thumbnailURL != nil {
            ThumbnailImage(
              fileId: store.file.fileId,
              url: thumbnailURL,
              size: CGSize(width: width, height: width * 9 / 16),
              cornerRadius: 20
            )
          } else {
            RoundedRectangle(cornerRadius: 20)
              .fill(LGColor.surfaceRaised)
              .overlay(
                Image(systemName: "film")
                  .font(.system(size: 64))
                  .foregroundStyle(OMDPalette.playback.opacity(0.8))
                  .shadow(color: OMDPalette.playback.opacity(0.5), radius: 16)
              )
          }

          stateOverlay
        }
        .frame(width: width, height: width * 9 / 16)
      }
      .aspectRatio(16 / 9, contentMode: .fit)

      if let duration = store.file.duration {
        DurationBadgeView(duration: MetadataFormatters.formatDuration(duration), style: .neonConsole)
          .padding(Spacing.s300)
      }
    }
    .glassCard(tint: OMDPalette.primary)
  }

  private var stateOverlay: some View {
    ZStack {
      if store.isDownloaded {
        playOverlayButton
      } else if store.isDownloading {
        downloadingOverlay
      } else if store.file.url != nil {
        downloadOverlayButton
      } else {
        processingOverlay
      }
    }
  }

  private var playOverlayButton: some View {
    Button {
      store.send(.playButtonTapped)
    } label: {
      Circle()
        .fill(.black.opacity(0.5))
        .frame(width: 72, height: 72)
        .overlay {
          Image(systemName: "play.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white)
            .offset(x: 2) // Optical centering
        }
    }
    .accessibilityLabel("Play")
  }

  private var downloadingOverlay: some View {
    Circle()
      .fill(.black.opacity(0.6))
      .frame(width: 80, height: 80)
      .overlay {
        VStack(spacing: 4) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(.white)
          Text("\(Int(store.downloadProgress * 100))%")
            .font(OMDFont.mono(12))
            .foregroundStyle(.white)
        }
      }
  }

  private var downloadOverlayButton: some View {
    Button {
      store.send(.downloadButtonTapped)
    } label: {
      Circle()
        .fill(.black.opacity(0.5))
        .frame(width: 72, height: 72)
        .overlay {
          Image(systemName: "arrow.down")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white)
        }
    }
    .accessibilityLabel("Download")
  }

  private var processingOverlay: some View {
    Circle()
      .fill(.black.opacity(0.5))
      .frame(width: 72, height: 72)
      .overlay {
        VStack(spacing: 4) {
          Image(systemName: "clock.fill")
            .font(.system(size: 24))
            .foregroundStyle(OMDPalette.queued)
          Text("Processing")
            .font(OMDFont.regular(11))
            .foregroundStyle(.white)
        }
      }
  }

  // MARK: - Metadata Slot

  private var metadataSlot: some View {
    VStack(alignment: .leading, spacing: Spacing.s400) {
      // Title + author (author = playback/identity cyan)
      VStack(alignment: .leading, spacing: Spacing.s100) {
        if let title = store.file.title {
          Text(title)
            .font(OMDFont.bold(20))
            .foregroundStyle(LGColor.textTitle)
        }

        if let author = store.file.authorName {
          Text(author)
            .font(OMDFont.medium(14))
            .foregroundStyle(OMDPalette.playback)
            .shadow(color: OMDPalette.playback.opacity(0.4), radius: 4)
        }
      }

      // Metric blocks — views = playback (cyan), duration = primary (blue),
      // size = storage/queued (amber).
      HStack(alignment: .top, spacing: Spacing.s300) {
        if let viewCount = store.file.viewCount {
          neonMetric(
            value: MetadataFormatters.formatViewCount(viewCount).replacingOccurrences(of: " views", with: ""),
            label: "VIEWS",
            icon: "eye.fill",
            accent: OMDPalette.playback
          )
        }

        if let duration = store.file.duration {
          neonMetric(
            value: MetadataFormatters.formatDuration(duration),
            label: "DURATION",
            icon: "timer",
            accent: OMDPalette.primary
          )
        }

        if let size = store.file.size {
          neonMetric(
            value: formatFileSize(size),
            label: "SIZE",
            icon: "internaldrive.fill",
            accent: OMDPalette.queued
          )
        }
      }

      // File details row: published date + size
      HStack(spacing: Spacing.s300) {
        if let date = store.file.publishDate {
          Label(formatDate(date), systemImage: "calendar")
            .font(OMDFont.mono(11))
            .foregroundStyle(LGColor.textSubtle)
        }

        Spacer()

        if let size = store.file.size {
          Label(formatFileSize(size), systemImage: "doc.fill")
            .font(OMDFont.mono(11))
            .foregroundStyle(LGColor.textSubtle)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Description Slot

  @ViewBuilder
  private var descriptionSlot: some View {
    if let description = store.file.description, !description.isEmpty {
      VStack(alignment: .leading, spacing: Spacing.s200) {
        Text("About")
          .font(OMDFont.bold(12))
          .foregroundStyle(OMDPalette.content)
          .textCase(.uppercase)
          .shadow(color: OMDPalette.content.opacity(0.4), radius: 3)

        ExpandableText(description, lineLimit: 3)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .neonCard(accent: OMDPalette.content)
    }
  }

  // MARK: - Actions Slot

  private var actionsSlot: some View {
    VStack(spacing: Spacing.s400) {
      if store.isDeleting {
        HStack(spacing: Spacing.s300) {
          ProgressView()
            .tint(.white)
          Text("Deleting…")
            .font(OMDFont.medium(14))
            .foregroundStyle(LGColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s300)
      } else if store.isDownloading {
        LGButton("Cancel Download", variant: .destructive, accent: OMDPalette.destructive) {
          store.send(.cancelDownloadButtonTapped)
        }

        ProgressView(value: store.downloadProgress)
          .progressViewStyle(.linear)
          .tint(OMDPalette.primary)
      } else if store.isDownloaded {
        LGButton("Play Video", variant: .primary, accent: OMDPalette.primary) {
          store.send(.playButtonTapped)
        }
        .shadow(color: OMDPalette.primary.opacity(0.6), radius: 12, x: 0, y: 4)
      } else if store.file.url != nil {
        LGButton("Download", variant: .primary, accent: OMDPalette.primary) {
          store.send(.downloadButtonTapped)
        }
        .shadow(color: OMDPalette.primary.opacity(0.6), radius: 12, x: 0, y: 4)
      }

      // Secondary action tiles: play (when downloaded), share (when downloaded),
      // delete (always). Mirrors the prior view's conditional affordances.
      HStack(spacing: Spacing.s200) {
        if store.isDownloaded {
          secondaryButton(label: "Play", icon: "play.fill", accent: OMDPalette.playback) {
            store.send(.playButtonTapped)
          }
          secondaryButton(label: "Share", icon: "square.and.arrow.up", accent: OMDPalette.primary) {
            store.send(.shareButtonTapped)
          }
        }

        secondaryButton(label: "Delete", icon: "trash", accent: OMDPalette.destructive) {
          store.send(.deleteButtonTapped)
        }
        .disabled(store.isDeleting)
      }
    }
  }

  // MARK: - Building Blocks

  private func neonMetric(value: String, label: String, icon: String, accent: Color) -> some View {
    MetricContentView(label: label, value: value, systemImage: icon, accent: accent)
      .neonCard(accent: accent)
  }

  private func secondaryButton(
    label: String,
    icon: String,
    accent: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 16))
          .foregroundStyle(accent)
          .shadow(color: accent.opacity(0.5), radius: 4)

        Text(label)
          .font(OMDFont.medium(10))
          .foregroundStyle(LGColor.textMuted)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Spacing.s300)
      .padding(.horizontal, Spacing.s100)
      .background(LGColor.surfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(accent.opacity(0.3), lineWidth: 1)
      )
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(.rect)
    .accessibilityLabel(label)
  }

  // MARK: - Formatters

  private static let fileSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
  }()

  private static let mediumDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
  }()

  private func formatFileSize(_ bytes: Int) -> String {
    Self.fileSizeFormatter.string(fromByteCount: Int64(bytes))
  }

  private func formatDate(_ date: Date) -> String {
    Self.mediumDateFormatter.string(from: date)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    FileDetailView(
      store: Store(
        initialState: FileDetailFeature.State(
          file: File(
            fileId: "preview-1",
            key: "sample.mp4",
            publishDate: Date(),
            size: 1_258_291_200,
            url: URL(string: "https://example.com/sample.mp4"),
            title: "SwiftUI State Management Deep Dive",
            description: "A deep dive into SwiftUI's state management system, exploring how data flows through your app.",
            authorName: "Point-Free",
            duration: 6138,
            viewCount: 142_300,
            thumbnailUrl: nil
          ),
          isDownloaded: true
        )
      ) {
        FileDetailFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
