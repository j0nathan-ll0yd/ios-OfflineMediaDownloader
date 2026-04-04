import SwiftUI
import ComposableArchitecture
import DesignSystem
import SharedModels
import FileClient
import FileCellFeature
import FileDetailFeature
import DefaultFilesFeature
import OrderedCollections

// MARK: - FileListView

public struct FileListView: View {
  @Bindable var store: StoreOf<FileListFeature>
  @Dependency(\.fileClient) var fileClient  // For fullScreenCover local URL conversion

  private let theme = DarkProfessionalTheme()

  public init(store: StoreOf<FileListFeature>) {
    self.store = store
  }

  public var body: some View {
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
  private func videoPlayerContent(for file: SharedModels.File) -> some View {
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

// MARK: - PendingFilesView

public struct PendingFilesView: View {
  let fileIds: OrderedSet<String>

  private let theme = DarkProfessionalTheme()

  public init(fileIds: OrderedSet<String>) {
    self.fileIds = fileIds
  }

  public var body: some View {
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
