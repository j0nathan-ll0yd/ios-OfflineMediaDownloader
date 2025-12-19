import SwiftUI
import ComposableArchitecture

struct FileDetailView: View {
  @Bindable var store: StoreOf<FileDetailFeature>

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Thumbnail/Preview
        thumbnailSection

        // File Info
        infoSection

        // Action Buttons
        actionSection

        Spacer()
      }
      .padding()
    }
    .navigationTitle(store.file.title ?? store.file.key)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if store.isDownloaded {
          Button {
            store.send(.shareButtonTapped)
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
        }
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  // MARK: - Thumbnail Section

  private var thumbnailSection: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 200)

      if store.isDownloaded {
        Image(systemName: "play.circle.fill")
          .font(.system(size: 64))
          .foregroundColor(.blue)
          .onTapGesture {
            store.send(.playButtonTapped)
          }
      } else if store.isDownloading {
        VStack(spacing: 12) {
          ProgressView()
            .scaleEffect(1.5)
          Text("\(Int(store.downloadProgress * 100))%")
            .font(.headline)
            .monospacedDigit()
        }
      } else if store.file.url != nil {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 64))
          .foregroundColor(.blue)
          .onTapGesture {
            store.send(.downloadButtonTapped)
          }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "clock.fill")
            .font(.system(size: 48))
            .foregroundColor(.orange)
          Text("Processing...")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
    }
  }

  // MARK: - Info Section

  private var infoSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Title
      if let title = store.file.title {
        VStack(alignment: .leading, spacing: 4) {
          Text("Title")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(title)
            .font(.headline)
        }
      }

      // Author
      if let author = store.file.authorName {
        VStack(alignment: .leading, spacing: 4) {
          Text("Author")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(author)
            .font(.body)
        }
      }

      // Description
      if let description = store.file.description {
        VStack(alignment: .leading, spacing: 4) {
          Text("Description")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(description)
            .font(.body)
        }
      }

      // File Details
      HStack(spacing: 24) {
        if let size = store.file.size {
          VStack(alignment: .leading, spacing: 4) {
            Text("Size")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(formatFileSize(size))
              .font(.body)
              .monospacedDigit()
          }
        }

        if let date = store.file.publishDate {
          VStack(alignment: .leading, spacing: 4) {
            Text("Date")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(date, style: .date)
              .font(.body)
          }
        }
      }

      // Status
      VStack(alignment: .leading, spacing: 4) {
        Text("Status")
          .font(.caption)
          .foregroundColor(.secondary)
        HStack {
          Image(systemName: statusIcon)
            .foregroundColor(statusColor)
          Text(statusText)
            .font(.body)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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

        ProgressView(value: store.downloadProgress)
          .progressViewStyle(.linear)
      } else if store.isDownloaded {
        Button {
          store.send(.playButtonTapped)
        } label: {
          Label("Play", systemImage: "play.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        Button(role: .destructive) {
          store.send(.deleteButtonTapped)
        } label: {
          Label("Delete", systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      } else if store.file.url != nil {
        Button {
          store.send(.downloadButtonTapped)
        } label: {
          Label("Download", systemImage: "arrow.down.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }

  // MARK: - Helpers

  private var statusIcon: String {
    if store.isDownloaded {
      return "checkmark.circle.fill"
    } else if store.isDownloading {
      return "arrow.down.circle"
    } else if store.file.url == nil {
      return "clock.fill"
    } else {
      return "icloud.and.arrow.down"
    }
  }

  private var statusColor: Color {
    if store.isDownloaded {
      return .green
    } else if store.isDownloading {
      return .blue
    } else if store.file.url == nil {
      return .orange
    } else {
      return .secondary
    }
  }

  private var statusText: String {
    if store.isDownloaded {
      return "Downloaded"
    } else if store.isDownloading {
      return "Downloading..."
    } else if store.file.url == nil {
      return "Processing"
    } else {
      return "Available for download"
    }
  }

  private func formatFileSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
}

#Preview("Downloaded") {
  NavigationStack {
    FileDetailView(store: Store(
      initialState: FileDetailFeature.State(
        file: File(
          fileId: "1",
          key: "Sample Video.mp4",
          publishDate: Date(),
          size: 1024 * 1024 * 150,
          url: URL(string: "https://example.com/video.mp4")
        ),
        isDownloaded: true
      )
    ) {
      FileDetailFeature()
    })
  }
}

#Preview("Not Downloaded") {
  NavigationStack {
    FileDetailView(store: Store(
      initialState: FileDetailFeature.State(
        file: File(
          fileId: "2",
          key: "Another Video.mp4",
          publishDate: Date(),
          size: 1024 * 1024 * 80,
          url: URL(string: "https://example.com/video2.mp4")
        )
      )
    ) {
      FileDetailFeature()
    })
  }
}

#Preview("Pending") {
  NavigationStack {
    FileDetailView(store: Store(
      initialState: FileDetailFeature.State(
        file: File(
          fileId: "3",
          key: "Processing Video.mp4",
          publishDate: nil,
          size: nil,
          url: nil
        )
      )
    ) {
      FileDetailFeature()
    })
  }
}
