import ComposableArchitecture
import DesignSystem
import SharedModels
import SwiftUI
import ThumbnailCacheClient

public struct FileDetailView: View {
  @Bindable var store: StoreOf<FileDetailFeature>

  private let theme = DarkProfessionalTheme()

  public init(store: StoreOf<FileDetailFeature>) {
    self.store = store
  }

  /// Parse thumbnailUrl string to URL
  private var thumbnailURL: URL? {
    guard let urlString = store.file.thumbnailUrl else { return nil }
    return URL(string: urlString)
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        // Thumbnail/Preview (16:9 aspect ratio)
        thumbnailSection

        // File Info
        VStack(alignment: .leading, spacing: 20) {
          // Title
          if let title = store.file.title {
            Text(title)
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
          }

          // Author with accent color
          if let author = store.file.authorName {
            Text(author)
              .font(.body)
              .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
          }

          // Statistics row: Views | Uploaded | Duration
          statsRow

          // Description (expandable with clickable links)
          if let description = store.file.description, !description.isEmpty {
            ExpandableText(description, lineLimit: 3)
          }

          Divider()
            .background(theme.textSecondary.opacity(0.3))

          // File details: Size | Published date
          fileDetailsRow

          // Status
          statusSection

          // Action Buttons
          actionSection
        }
        .padding(20)
      }
    }
    .background(theme.backgroundColor)
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if store.isDownloaded {
          Button {
            store.send(.shareButtonTapped)
          } label: {
            Image(systemName: "square.and.arrow.up")
              .foregroundStyle(theme.primaryColor)
          }
        }
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .preferredColorScheme(.dark)
  }

  // MARK: - Thumbnail Section

  private var thumbnailSection: some View {
    ZStack(alignment: .bottomTrailing) {
      // Thumbnail or placeholder
      if thumbnailURL != nil {
        ThumbnailImage(
          fileId: store.file.fileId,
          url: thumbnailURL,
          size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 9 / 16),
          cornerRadius: 0
        )
      } else {
        Rectangle()
          .fill(Color(white: 0.15))
          .aspectRatio(16 / 9, contentMode: .fit)
          .overlay {
            Image(systemName: "film")
              .font(.system(size: 48))
              .foregroundStyle(.secondary)
          }
      }

      // Duration badge
      if let duration = store.file.duration {
        DurationBadge(seconds: duration)
          .padding(12)
      }

      // State overlay (centered)
      stateOverlay
    }
    .aspectRatio(16 / 9, contentMode: .fit)
  }

  private var stateOverlay: some View {
    ZStack {
      if store.isDownloaded {
        // Play button
        Circle()
          .fill(.black.opacity(0.5))
          .frame(width: 72, height: 72)
          .overlay {
            Image(systemName: "play.fill")
              .font(.system(size: 28))
              .foregroundStyle(.white)
              .offset(x: 2) // Optical centering
          }
          .onTapGesture {
            store.send(.playButtonTapped)
          }
      } else if store.isDownloading {
        // Download progress
        Circle()
          .fill(.black.opacity(0.6))
          .frame(width: 80, height: 80)
          .overlay {
            VStack(spacing: 4) {
              ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
              Text("\(Int(store.downloadProgress * 100))%")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .monospacedDigit()
            }
          }
      } else if store.file.url != nil {
        // Download available
        Circle()
          .fill(.black.opacity(0.5))
          .frame(width: 72, height: 72)
          .overlay {
            Image(systemName: "arrow.down")
              .font(.system(size: 28, weight: .semibold))
              .foregroundStyle(.white)
          }
          .onTapGesture {
            store.send(.downloadButtonTapped)
          }
      } else {
        // Pending
        Circle()
          .fill(.black.opacity(0.5))
          .frame(width: 72, height: 72)
          .overlay {
            VStack(spacing: 4) {
              Image(systemName: "clock.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
              Text("Processing")
                .font(.caption2)
                .foregroundStyle(.white)
            }
          }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Stats Row

  private var statsRow: some View {
    HStack(spacing: 20) {
      if let viewCount = store.file.viewCount {
        StatItem(label: "Views", value: MetadataFormatters.formatViewCount(viewCount).replacingOccurrences(of: " views", with: ""))
      }

      if let uploadDate = store.file.uploadDate {
        StatItem(label: "Uploaded", value: formatUploadDate(uploadDate))
      }

      if let duration = store.file.duration {
        StatItem(label: "Duration", value: MetadataFormatters.formatDuration(duration))
      }
    }
  }

  // MARK: - File Details Row

  private var fileDetailsRow: some View {
    HStack(spacing: 20) {
      if let size = store.file.size {
        StatItem(label: "File Size", value: formatFileSize(size))
      }

      if let date = store.file.publishDate {
        StatItem(label: "Downloaded", value: formatDate(date))
      }
    }
  }

  // MARK: - Status Section

  private var statusSection: some View {
    HStack(spacing: 8) {
      Image(systemName: statusIcon)
        .foregroundStyle(statusColor)
      Text(statusText)
        .font(.subheadline)
        .foregroundStyle(theme.textSecondary)
    }
    .padding(.vertical, 8)
  }

  // MARK: - Action Section

  private var actionSection: some View {
    VStack(spacing: 12) {
      if store.isDownloading {
        Button(role: .cancel) {
          store.send(.cancelDownloadButtonTapped)
        } label: {
          Label("Cancel Download", systemImage: "xmark.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)

        ProgressView(value: store.downloadProgress)
          .progressViewStyle(.linear)
          .tint(theme.primaryColor)
      } else if store.isDownloaded {
        Button {
          store.send(.playButtonTapped)
        } label: {
          Label("Play Video", systemImage: "play.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.primaryColor)

        Button(role: .destructive) {
          store.send(.deleteButtonTapped)
        } label: {
          Label("Delete from Device", systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      } else if store.file.url != nil {
        Button {
          store.send(.downloadButtonTapped)
        } label: {
          Label("Download", systemImage: "arrow.down.circle")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.primaryColor)
      }
    }
  }

  // MARK: - Helpers

  private var statusIcon: String {
    if store.isDownloaded {
      "checkmark.circle.fill"
    } else if store.isDownloading {
      "arrow.down.circle"
    } else if store.file.url == nil {
      "clock.fill"
    } else {
      "icloud.and.arrow.down"
    }
  }

  private var statusColor: Color {
    if store.isDownloaded {
      theme.successColor
    } else if store.isDownloading {
      theme.primaryColor
    } else if store.file.url == nil {
      theme.warningColor
    } else {
      theme.textSecondary
    }
  }

  private var statusText: String {
    if store.isDownloaded {
      "Downloaded"
    } else if store.isDownloading {
      "Downloading..."
    } else if store.file.url == nil {
      "Processing"
    } else {
      "Available for download"
    }
  }

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

  /// Format upload date from YYYYMMDD string
  private func formatUploadDate(_ dateString: String) -> String {
    guard let date = DateFormatters.yyyyMMdd.date(from: dateString) else {
      return dateString
    }
    return MetadataFormatters.formatRelativeDate(date)
  }
}
