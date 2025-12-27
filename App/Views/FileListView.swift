import SwiftUI
import ComposableArchitecture
import AVKit
import UIKit

// MARK: - FileCellView

struct FileCellView: View {
  @Bindable var store: StoreOf<FileCellFeature>

  /// Thumbnail action based on current state
  private var thumbnailAction: (() -> Void)? {
    // Pending files have no action
    if store.state.isPending { return nil }
    if store.isDownloading { return { store.send(.cancelDownloadButtonTapped) } }
    if store.isDownloaded { return { store.send(.playButtonTapped) } }
    return { store.send(.downloadButtonTapped) }
  }

  var body: some View {
    HStack(spacing: 12) {
      // Thumbnail - tappable action based on state
      ZStack {
        // Gradient background - different color for pending state
        LinearGradient(
          colors: store.state.isPending
            ? [.orange.opacity(0.7), .yellow.opacity(0.7)]
            : [.blue.opacity(0.8), .purple.opacity(0.8)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .frame(width: 100, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 10))

        // State overlay icon
        if store.state.isPending {
          // Pending - clock icon
          VStack(spacing: 2) {
            Image(systemName: "clock")
              .font(.title3)
              .foregroundColor(.white)
            Text("Processing")
              .font(.system(size: 8, weight: .medium))
              .foregroundColor(.white.opacity(0.9))
          }
        } else if store.isDownloading {
          // Progress ring with cancel X
          ZStack {
            Circle()
              .stroke(Color.white.opacity(0.3), lineWidth: 3)
            Circle()
              .trim(from: 0, to: store.downloadProgress)
              .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
              .rotationEffect(.degrees(-90))
            Image(systemName: "xmark")
              .font(.caption)
              .fontWeight(.bold)
              .foregroundColor(.white)
          }
          .frame(width: 36, height: 36)
        } else if store.isDownloaded {
          // Play icon
          Image(systemName: "play.fill")
            .font(.title2)
            .foregroundColor(.white)
        } else {
          // Download icon
          Image(systemName: "arrow.down.to.line")
            .font(.title2)
            .foregroundColor(.white)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        thumbnailAction?()
      }

      // Content
      VStack(alignment: .leading, spacing: 4) {
        Text(store.file.title ?? store.file.key)
          .font(.subheadline)
          .fontWeight(.medium)
          .lineLimit(2)

        if let author = store.file.authorName {
          Text(author)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        HStack(spacing: 4) {
          if let date = store.file.publishDate {
            Text(date, style: .relative)
          }

          if store.file.publishDate != nil && store.file.size != nil {
            Text("•")
          }

          if let size = store.file.size, size > 0 {
            Text(formatFileSize(size))
          }
        }
        .font(.caption2)
        .foregroundColor(.secondary)

        // Status text based on state
        if store.state.isPending {
          Text("Processing on server...")
            .font(.caption2)
            .foregroundColor(.orange)
        } else if store.isDownloading {
          Text("Downloading \(Int(store.downloadProgress * 100))% — Tap to cancel")
            .font(.caption2)
            .foregroundColor(.blue)
        }
      }

      Spacer()
    }
    .padding(.vertical, 6)
    .task {
      store.send(.onAppear)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

/// Format bytes to human-readable string (e.g., "45 MB")
private func formatFileSize(_ bytes: Int?) -> String {
  guard let bytes = bytes, bytes > 0 else { return "" }
  let mb = Double(bytes) / 1_000_000
  if mb >= 1000 {
    return String(format: "%.1f GB", mb / 1000)
  }
  return String(format: "%.0f MB", mb)
}

// MARK: - FileListView

struct FileListView: View {
  @Bindable var store: StoreOf<FileListFeature>
  @Dependency(\.fileClient) var fileClient  // For fullScreenCover local URL conversion

  var body: some View {
    NavigationStack {
      fileListContent
        .navigationTitle("Files")
        .toolbar { toolbarContent }
        .confirmationDialog(
          "Add Video",
          isPresented: Binding(
            get: { store.showAddConfirmation },
            set: { _ in store.send(.confirmationDismissed) }
          ),
          titleVisibility: .visible
        ) {
          Button("From Clipboard") {
            store.send(.addFromClipboard)
          }
          Button("Cancel", role: .cancel) {
            store.send(.confirmationDismissed)
          }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .navigationDestination(
          item: $store.scope(state: \.selectedFile, action: \.detail)
        ) { detailStore in
          FileDetailView(store: detailStore)
        }
    }
    .task {
      store.send(.onAppear)
      // Pre-warm pasteboard access (triggers permission dialog if needed)
      Task.detached(priority: .background) {
        _ = UIPasteboard.general.hasStrings
      }
    }
    .fullScreenCover(
      item: Binding(
        get: { store.playingFile },
        set: { _ in store.send(.dismissPlayer) }
      )
    ) { file in
      videoPlayerContent(for: file)
    }
  }

  // MARK: - File List Content

  @ViewBuilder
  private var fileListContent: some View {
    if store.isLoading && store.files.isEmpty {
      ProgressView("Loading files...")
    } else if store.files.isEmpty {
      VStack(spacing: 16) {
        Image(systemName: "film.stack")
          .font(.system(size: 60))
          .foregroundColor(.secondary)
        Text("No files yet")
          .font(.headline)
        Text("Tap + to add a video from your clipboard")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    } else {
      List {
        ForEach(store.scope(state: \.files, action: \.files)) { cellStore in
          FileCellView(store: cellStore)
            .contentShape(Rectangle())
            .onTapGesture {
              store.send(.fileTapped(cellStore.state))
            }
        }
        .onDelete { indexSet in
          store.send(.deleteFiles(indexSet))
        }
      }
      .refreshable {
        store.send(.refreshButtonTapped)
      }
    }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      HStack {
        if !store.pendingFileIds.isEmpty {
          NavigationLink(destination: PendingFilesView(fileIds: store.pendingFileIds)) {
            Image(systemName: "clock.arrow.circlepath")
              .foregroundColor(.orange)
          }
        }

        Button {
          store.send(.refreshButtonTapped)
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(store.isLoading)

        Button {
          store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
    }
  }

  // MARK: - Video Player

  @ViewBuilder
  private func videoPlayerContent(for file: File) -> some View {
    if let remoteURL = file.url {
      let localURL = fileClient.filePath(remoteURL)
      VideoPlayerSheet(url: localURL) {
        store.send(.dismissPlayer)
      }
    } else {
      Text("No URL available for this file")
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
  }
}

struct PendingFilesView: View {
  let fileIds: [String]

  var body: some View {
    List {
      Section(header: Text("Pending Downloads")) {
        ForEach(fileIds, id: \.self) { id in
          HStack {
            Image(systemName: "clock")
              .foregroundColor(.orange)
            Text(id)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      Section {
        Text("These videos are being processed by the server. They will appear in your Files list when ready.")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .navigationTitle("Pending")
  }
}

#Preview {
  FileListView(
    store: Store(initialState: FileListFeature.State()) {
      FileListFeature()
    }
  )
}
