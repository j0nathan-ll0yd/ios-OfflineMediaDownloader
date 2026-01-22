import SwiftUI
import ComposableArchitecture
import AVKit
import UIKit

// MARK: - FileCellView

struct FileCellView: View {
  @Bindable var store: StoreOf<FileCellFeature>

  private let theme = DarkProfessionalTheme()
  private let thumbnailSize = CGSize(width: 120, height: 68)

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

  var body: some View {
    HStack(spacing: 14) {
      // Thumbnail with duration badge
      ZStack(alignment: .bottomTrailing) {
        ThumbnailImage(url: thumbnailURL, size: thumbnailSize)

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
          if store.file.viewCount != nil && store.file.size != nil {
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

  private let theme = DarkProfessionalTheme()

  var body: some View {
    NavigationStack {
      ZStack {
        theme.backgroundColor
          .ignoresSafeArea()

        fileListContent
      }
      .navigationTitle("Files")
      .navigationBarTitleDisplayMode(.large)
      .toolbarColorScheme(.dark, for: .navigationBar)
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
    .preferredColorScheme(.dark)
    .overlay {
      // Loading overlay shown immediately when play is tapped
      if store.isPreparingToPlay {
        ZStack {
          Color.black.opacity(0.8)
            .ignoresSafeArea()
          ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
        }
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
    .sheet(
      isPresented: Binding(
        get: { store.sharingFileURL != nil },
        set: { if !$0 { store.send(.dismissShareSheet) } }
      )
    ) {
      if let url = store.sharingFileURL {
        ShareSheet(items: [url])
      }
    }
  }

  // MARK: - File List Content

  @ViewBuilder
  private var fileListContent: some View {
    // Show DefaultFilesView only for UNREGISTERED users with no files
    // Registered users (even if signed out) should never see default file
    if !store.isRegistered && store.files.isEmpty {
      DefaultFilesView(
        store: store.scope(state: \.defaultFiles, action: \.defaultFiles),
        onRegisterTapped: { store.send(.delegate(.loginRequired)) }
      )
    } else if store.isLoading && store.files.isEmpty {
      loadingView
    } else if store.files.isEmpty {
      emptyView
    } else {
      fileList
    }
  }

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)
        .tint(theme.primaryColor)
      Text("Loading files...")
        .font(.subheadline)
        .foregroundStyle(theme.textSecondary)
    }
  }

  private var emptyView: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .fill(theme.primaryColor.opacity(0.15))
          .frame(width: 100, height: 100)

        Image(systemName: "film.stack")
          .font(.system(size: 40))
          .foregroundStyle(theme.primaryColor)
      }

      VStack(spacing: 8) {
        Text("No files yet")
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundStyle(.white)

        Text("Tap + to add your first video")
          .font(.subheadline)
          .foregroundStyle(theme.textSecondary)
      }

      Button {
        store.send(.addButtonTapped)
      } label: {
        HStack {
          Image(systemName: "plus")
          Text("Add Video")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(theme.primaryColor)
        .clipShape(Capsule())
      }
    }
    .padding(32)
  }

  private var fileList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(store.scope(state: \.files, action: \.files)) { cellStore in
          FileCellView(store: cellStore)
            .contentShape(Rectangle())
            .onTapGesture {
              store.send(.fileTapped(cellStore.state))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) {
                if let index = store.files.firstIndex(where: { $0.id == cellStore.state.id }) {
                  store.send(.deleteFiles(IndexSet(integer: index)))
                }
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
        }
      }
      .padding(.vertical, 12)
    }
    .refreshable {
      store.send(.refreshButtonTapped)
    }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      HStack(spacing: 16) {
        if !store.pendingFileIds.isEmpty {
          NavigationLink(destination: PendingFilesView(fileIds: store.pendingFileIds)) {
            Image(systemName: "clock.arrow.circlepath")
              .foregroundStyle(theme.warningColor)
          }
        }

        Button {
          store.send(.refreshButtonTapped)
        } label: {
          Image(systemName: "arrow.clockwise")
            .foregroundStyle(theme.primaryColor)
        }
        .disabled(store.isLoading)

        Button {
          store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.title3)
            .foregroundStyle(theme.primaryColor)
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

  private let theme = DarkProfessionalTheme()

  var body: some View {
    ZStack {
      theme.backgroundColor
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 16) {
          // Header section
          VStack(spacing: 8) {
            Text("PENDING DOWNLOADS")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(theme.textSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(fileIds, id: \.self) { id in
              HStack(spacing: 12) {
                Image(systemName: "clock")
                  .font(.system(size: 18))
                  .foregroundStyle(theme.warningColor)

                Text(id)
                  .font(.subheadline)
                  .foregroundStyle(.white)
                  .lineLimit(1)

                Spacer()
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .background(theme.surfaceColor)
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
          }

          // Info section
          HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
              .foregroundStyle(theme.primaryColor)

            Text("These videos are being processed by the server. They will appear in your Files list when ready.")
              .font(.caption)
              .foregroundStyle(theme.textSecondary)
          }
          .padding(16)
          .background(theme.surfaceColor)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
      }
    }
    .navigationTitle("Pending")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .preferredColorScheme(.dark)
  }
}

#Preview {
  FileListView(
    store: Store(initialState: FileListFeature.State()) {
      FileListFeature()
    }
  )
}
