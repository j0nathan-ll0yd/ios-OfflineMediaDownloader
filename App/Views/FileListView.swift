import SwiftUI
import ComposableArchitecture
import AVKit

// MARK: - FileCellFeature

@Reducer
struct FileCellFeature {
  @ObservableState
  struct State: Equatable, Identifiable {
    var file: File
    var id: String { file.fileId }
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var isDownloaded: Bool = false  // Cached to avoid fileClient.fileExists() in view body

    /// File is pending when metadata is received but no download URL is available yet
    var isPending: Bool { file.url == nil }
  }

  enum Action {
    case onAppear
    case checkFileExistence(Bool)
    case playButtonTapped
    case downloadButtonTapped
    case cancelDownloadButtonTapped
    case deleteButtonTapped
    case downloadProgressUpdated(Double)
    case downloadCompleted(URL)
    case downloadFailed(String)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case fileDeleted(File)
      case playFile(File)
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.downloadClient) var downloadClient

  private enum CancelID { case download }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Check file existence in background, cache result in state
        guard let url = state.file.url else { return .none }
        return .run { [fileClient] send in
          let exists = fileClient.fileExists(url)
          await send(.checkFileExistence(exists))
        }

      case let .checkFileExistence(exists):
        state.isDownloaded = exists
        return .none

      case .playButtonTapped:
        return .send(.delegate(.playFile(state.file)))

      case .downloadButtonTapped:
        guard let remoteURL = state.file.url else {
          return .none
        }
        state.isDownloading = true
        state.downloadProgress = 0
        let expectedSize = Int64(state.file.size ?? 0)
        return .run { send in
          let stream = downloadClient.downloadFile(remoteURL, expectedSize)
          for await progress in stream {
            switch progress {
            case let .progress(percent):
              await send(.downloadProgressUpdated(Double(percent) / 100.0))
            case let .completed(localURL):
              await send(.downloadCompleted(localURL))
            case let .failed(message):
              await send(.downloadFailed(message))
            }
          }
        }
        .cancellable(id: CancelID.download, cancelInFlight: true)

      case .cancelDownloadButtonTapped:
        state.isDownloading = false
        state.downloadProgress = 0
        if let url = state.file.url {
          return .run { _ in
            await downloadClient.cancelDownload(url)
          }
          .merge(with: .cancel(id: CancelID.download))
        }
        return .cancel(id: CancelID.download)

      case let .downloadProgressUpdated(progress):
        state.downloadProgress = progress
        return .none

      case .downloadCompleted:
        state.isDownloading = false
        state.downloadProgress = 1.0
        state.isDownloaded = true  // Update cached state
        return .none

      case let .downloadFailed(message):
        print("❌ Download failed: \(message)")
        state.isDownloading = false
        state.downloadProgress = 0
        return .none

      case .deleteButtonTapped:
        let file = state.file
        return .run { send in
          try await coreDataClient.deleteFile(file)
          if let url = file.url, fileClient.fileExists(url) {
            try await fileClient.deleteFile(url)
          }
          await send(.delegate(.fileDeleted(file)))
        }

      case .delegate:
        return .none
      }
    }
  }
}

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
    .onAppear {
      store.send(.onAppear)
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

@Reducer
struct FileListFeature {
  @ObservableState
  struct State: Equatable {
    var files: IdentifiedArrayOf<FileCellFeature.State> = []
    var pendingFileIds: [String] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showAddConfirmation: Bool = false
    var playingFile: File?
  }

  enum Action {
    case onAppear
    case refreshButtonTapped
    case addButtonTapped
    case addFromClipboard
    case confirmationDismissed
    case clearError
    case setError(String)
    case addPendingFileId(String)
    case localFilesLoaded([File])
    case remoteFilesResponse(Result<FileResponse, Error>)
    case addFileResponse(Result<DownloadFileResponse, Error>)
    case files(IdentifiedActionOf<FileCellFeature>)
    case deleteFiles(IndexSet)
    case dismissPlayer
    // Push notification actions
    case fileAddedFromPush(File)
    case updateFileUrl(fileId: String, url: URL)
    case refreshFileState(String)  // fileId
    case delegate(Delegate)

    enum Delegate: Equatable {
      case authenticationRequired
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Load cached files immediately - no server call, no loading state
        // User must explicitly refresh to fetch from server
        return .run { send in
          let files = try await coreDataClient.getFiles()
          await send(.localFilesLoaded(files))
        }

      case let .localFilesLoaded(files):
        // Preserve existing UI state (download status) when reloading
        let existingStates = Dictionary(uniqueKeysWithValues: state.files.map { ($0.id, $0) })
        state.files = IdentifiedArray(uniqueElements: files.map { file in
          var newState = FileCellFeature.State(file: file)
          if let existing = existingStates[file.fileId] {
            newState.isDownloaded = existing.isDownloaded
            newState.isDownloading = existing.isDownloading
            newState.downloadProgress = existing.downloadProgress
          }
          return newState
        })
        state.isLoading = false
        return .none

      case .refreshButtonTapped:
        state.isLoading = true
        return .run { send in
          await send(.remoteFilesResponse(Result {
            try await serverClient.getFiles()
          }))
        }

      case let .remoteFilesResponse(.success(response)):
        if let fileList = response.body {
          // Preserve existing UI state (download status) when refreshing
          let existingStates = Dictionary(uniqueKeysWithValues: state.files.map { ($0.id, $0) })
          state.files = IdentifiedArray(uniqueElements: fileList.contents.map { file in
            var newState = FileCellFeature.State(file: file)
            if let existing = existingStates[file.fileId] {
              newState.isDownloaded = existing.isDownloaded
              newState.isDownloading = existing.isDownloading
              newState.downloadProgress = existing.downloadProgress
            }
            return newState
          })
          // Remove pending IDs that are now available
          let availableIds = Set(fileList.contents.map { $0.fileId })
          state.pendingFileIds.removeAll { availableIds.contains($0) }
        }
        state.isLoading = false
        // Cache files to disk for instant display on next launch
        return .run { [files = response.body?.contents ?? []] _ in
          try await coreDataClient.cacheFiles(files)
        }

      case let .remoteFilesResponse(.failure(error)):
        state.isLoading = false
        // Check if this is an auth error - redirect to login
        if let serverError = error as? ServerClientError, serverError == .unauthorized {
          return .send(.delegate(.authenticationRequired))
        }
        state.errorMessage = error.localizedDescription
        return .none

      case .addButtonTapped:
        state.showAddConfirmation = true
        return .none

      case .confirmationDismissed:
        state.showAddConfirmation = false
        return .none

      case .clearError:
        state.errorMessage = nil
        return .none

      case let .setError(message):
        state.errorMessage = message
        return .none

      case let .addPendingFileId(fileId):
        state.pendingFileIds.append(fileId)
        return .none

      case .addFromClipboard:
        state.showAddConfirmation = false
        // Move pasteboard access to background thread to avoid blocking main thread (1-3s)
        return .run { send in
          let result = await Task.detached {
            guard UIPasteboard.general.hasStrings,
                  let urlString = UIPasteboard.general.string,
                  let url = URL(string: urlString) else {
              return nil as (URL, String?)?
            }
            return (url, urlString.youtubeID)
          }.value

          guard let (url, youtubeId) = result else {
            await send(.setError("Invalid URL in clipboard"))
            return
          }

          if let youtubeId = youtubeId {
            await send(.addPendingFileId(youtubeId))
          }

          await send(.addFileResponse(Result {
            try await serverClient.addFile(url: url)
          }))
        }

      case .addFileResponse(.success):
        return .none

      case let .addFileResponse(.failure(error)):
        // Check if this is an auth error - redirect to login
        if let serverError = error as? ServerClientError, serverError == .unauthorized {
          return .send(.delegate(.authenticationRequired))
        }
        state.errorMessage = error.localizedDescription
        return .none

      case .delegate:
        return .none

      case let .deleteFiles(indexSet):
        for index in indexSet {
          state.files.remove(at: index)
        }
        return .none

      case let .files(.element(id: _, action: .delegate(.fileDeleted(file)))):
        state.files.remove(id: file.fileId)
        return .none

      case let .files(.element(id: _, action: .delegate(.playFile(file)))):
        state.playingFile = file
        return .none

      case .dismissPlayer:
        state.playingFile = nil
        return .none

      // MARK: - Push Notification Actions
      case let .fileAddedFromPush(file):
        // Add or update file in the list
        if var existing = state.files[id: file.fileId] {
          // Preserve download state, update file metadata
          existing.file = file
          state.files[id: file.fileId] = existing
        } else {
          // Insert new file
          state.files.append(FileCellFeature.State(file: file))
        }
        // Sort by publishDate descending (newest first)
        state.files.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
        // Remove from pending if it was there
        state.pendingFileIds.removeAll { $0 == file.fileId }
        return .none

      case let .updateFileUrl(fileId, url):
        // Update the file's URL in state (called when download-ready notification arrives)
        if var fileState = state.files[id: fileId] {
          fileState.file.url = url
          state.files[id: fileId] = fileState
        }
        return .none

      case let .refreshFileState(fileId):
        // Trigger onAppear for the specific file cell to re-check download status
        return .send(.files(.element(id: fileId, action: .onAppear)))

      case .files:
        return .none
      }
    }
    .forEach(\.files, action: \.files) {
      FileCellFeature()
    }
  }
}

struct FileListView: View {
  @Bindable var store: StoreOf<FileListFeature>
  @Dependency(\.fileClient) var fileClient  // For fullScreenCover local URL conversion

  var body: some View {
    NavigationStack {
      Group {
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
      .navigationTitle("Files")
      .toolbar {
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
      .confirmationDialog(
        "Add Video",
        isPresented: Binding(
          get: { store.showAddConfirmation },
          set: { _ in store.send(.confirmationDismissed) }
        ),
        titleVisibility: .visible
      ) {
        // Always show button - validation happens in the action handler
        // (UIPasteboard.hasStrings can block main thread for >1s on first access)
        Button("From Clipboard") {
          store.send(.addFromClipboard)
        }
        Button("Cancel", role: .cancel) {
          store.send(.confirmationDismissed)
        }
      }
      .alert(
        "Error",
        isPresented: Binding(
          get: { store.errorMessage != nil },
          set: { if !$0 { store.send(.clearError) } }
        )
      ) {
        Button("OK") {
          store.send(.clearError)
        }
      } message: {
        Text(store.errorMessage ?? "")
      }
    }
    .onAppear {
      store.send(.onAppear)
      // Pre-warm pasteboard access in background to avoid first-tap latency
      // (UIPasteboard initialization can block main thread for >1s on first access)
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
      if let remoteURL = file.url {
        let localURL = fileClient.filePath(remoteURL)
        VideoPlayerView(url: localURL) {
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
}

// MARK: - Video Player View
struct VideoPlayerView: View {
  let url: URL
  let onDismiss: () -> Void
  @State private var player: AVPlayer?
  @State private var errorMessage: String?
  @State private var isLoading = true
  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false

  private let dismissThreshold: CGFloat = 150

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Background - fades as you drag down
        Color.black
          .opacity(1.0 - Double(abs(dragOffset)) / 400.0)
          .edgesIgnoringSafeArea(.all)

        // Content layer - moves with drag
        Group {
          if let errorMessage = errorMessage {
            VStack(spacing: 16) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
              Text("Playback Error")
                .font(.headline)
                .foregroundColor(.white)
              Text(errorMessage)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
          } else if let player = player {
            VideoPlayer(player: player)
              .edgesIgnoringSafeArea(.all)
          } else if isLoading {
            ProgressView()
              .scaleEffect(1.5)
              .tint(.white)
          }
        }
        .offset(y: dragOffset)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(.interactiveSpring(), value: isDragging)
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            // Only allow downward drags (positive translation)
            if value.translation.height > 0 {
              isDragging = true
              dragOffset = value.translation.height
            }
          }
          .onEnded { value in
            isDragging = false
            if value.translation.height > dismissThreshold {
              // Dismiss with animation
              withAnimation(.easeOut(duration: 0.2)) {
                dragOffset = geometry.size.height
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
              }
            } else {
              // Snap back
              withAnimation(.interactiveSpring()) {
                dragOffset = 0
              }
            }
          }
      )
    }
    .onAppear {
      setupAndPlay()
    }
    .onDisappear {
      player?.pause()
      player = nil
    }
  }

  private func setupAndPlay() {
    print("🎬 VideoPlayerView: Playing: \(url.lastPathComponent)")

    // Move all file system and audio session setup to background thread
    Task.detached {
      // File existence check
      guard FileManager.default.fileExists(atPath: url.path) else {
        await MainActor.run {
          errorMessage = "File not found"
          isLoading = false
        }
        return
      }

      // Quick size check for corrupted files
      if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
         let size = attrs[.size] as? Int64, size < 100_000 {
        await MainActor.run {
          errorMessage = "File corrupted (\(size) bytes).\nDelete and re-download."
          isLoading = false
        }
        return
      }

      // Setup audio session (can block 100-300ms)
      do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        print("🎬 Audio session error: \(error)")
      }

      // Create player and start playback on main thread
      await MainActor.run {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = newPlayer
        self.isLoading = false
        newPlayer.play()
      }
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
