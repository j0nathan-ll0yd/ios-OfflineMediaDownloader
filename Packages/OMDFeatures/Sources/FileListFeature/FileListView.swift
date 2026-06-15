import ComposableArchitecture
import DefaultFilesFeature
import DesignSystem
import FileCellFeature
import FileClient
import FileDetailFeature
import LifegamesTemplates
import OrderedCollections
import SharedModels
import SwiftUI

// MARK: - FileListView

public struct FileListView: View {
  @Bindable var store: StoreOf<FileListFeature>
  @Dependency(\.fileClient) var fileClient // For fullScreenCover local URL conversion

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

  private var fileListContent: some View {
    Group {
      if !store.isRegistered, store.files.isEmpty, !store.hasCompletedInitialLoad {
        skeletonFileList
      } else if !store.isRegistered, store.files.isEmpty {
        DefaultFilesView(
          store: store.scope(state: \.defaultFiles, action: \.defaultFiles),
          onRegisterTapped: { store.send(.delegate(.loginRequired)) }
        )
      } else if !store.hasCompletedInitialLoad, store.files.isEmpty {
        skeletonFileList
      } else if store.files.isEmpty {
        emptyView
      } else {
        fileList
      }
    }
    .animation(.snappy, value: store.hasCompletedInitialLoad)
  }

  // MARK: - Skeleton Loading

  private var skeletonFileList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(0 ..< 4, id: \.self) { _ in
          skeletonCell
        }
      }
      .padding(.vertical, 12)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading files")
  }

  private var skeletonCell: some View {
    HStack(spacing: 14) {
      RoundedRectangle(cornerRadius: 8)
        .fill(theme.surfaceColor)
        .frame(width: 120, height: 68)

      VStack(alignment: .leading, spacing: 3) {
        RoundedRectangle(cornerRadius: 4)
          .fill(theme.surfaceColor)
          .frame(height: 16)
          .frame(maxWidth: .infinity, alignment: .leading)

        RoundedRectangle(cornerRadius: 4)
          .fill(theme.surfaceColor)
          .frame(width: 100, height: 12)

        RoundedRectangle(cornerRadius: 4)
          .fill(theme.surfaceColor)
          .frame(width: 140, height: 12)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .modifier(ShimmerModifier())
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
    ListTemplate(
      items: Array(store.scope(state: \.files, action: \.files)),
      accent: OMDPalette.primary,
      emptyState: nil,
      onRefresh: { await store.send(.refreshButtonTapped) }
    ) { cellStore in
      SwipeableRow(
        cellStore: cellStore,
        isDeleting: store.deletingFileId == cellStore.id,
        onConfirmDelete: {
          // SwipeableRow already confirmed via its local dialog: set the delete
          // target by id, then execute it (mirrors the original two-step flow;
          // .deleteFile(id:) only stages state.fileToDelete and returns .none).
          store.send(.deleteFile(id: cellStore.id))
          store.send(.confirmDeleteFile)
        },
        onTap: {
          store.send(.fileTapped(cellStore.state))
        }
      )
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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

// MARK: - SwipeableRow

private struct SwipeableRow: View {
  let cellStore: StoreOf<FileCellFeature>
  let isDeleting: Bool
  let onConfirmDelete: () -> Void
  let onTap: () -> Void

  @State private var baseOffset: CGFloat = 0
  @State private var dragTranslation: CGFloat = 0
  @State private var showConfirmation = false

  private let revealWidth: CGFloat = 80
  private let theme = DarkProfessionalTheme()

  private var offset: CGFloat {
    min(0, max(-revealWidth, baseOffset + dragTranslation))
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      // Delete button visual (behind foreground, not interactive)
      HStack {
        Spacer()
        Image(systemName: "trash")
          .font(.title3)
          .foregroundColor(.white)
          .frame(width: revealWidth)
          .frame(maxHeight: .infinity)
          .background(Color.red)
      }

      // Foreground cell
      FileCellView(store: cellStore)
        .background(theme.backgroundColor)
        .offset(x: offset)
        .contentShape(Rectangle())
        .onTapGesture {
          if offset < -5 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              baseOffset = 0
            }
          } else {
            onTap()
          }
        }
    }
    .clipped()
    .overlay(alignment: .trailing) {
      // Invisible tap target over revealed delete area (renders on top, gets hit priority)
      if offset < -5 {
        Color.clear
          .frame(width: -offset)
          .contentShape(Rectangle())
          .onTapGesture {
            showConfirmation = true
          }
      }
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 30)
        .onChanged { value in
          guard abs(value.translation.width) > abs(value.translation.height) else { return }
          dragTranslation = value.translation.width
        }
        .onEnded { value in
          let finalOffset = baseOffset + value.translation.width
          baseOffset = min(0, max(-revealWidth, finalOffset))
          dragTranslation = 0
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if baseOffset < -revealWidth / 2 || value.velocity.width < -500 {
              baseOffset = -revealWidth
            } else {
              baseOffset = 0
            }
          }
        }
    )
    .confirmationDialog(
      "Delete Video?",
      isPresented: $showConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          baseOffset = 0
        }
        onConfirmDelete()
      }
      Button("Cancel", role: .cancel) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          baseOffset = 0
        }
      }
    }
    .onChange(of: showConfirmation) { _, isShowing in
      if !isShowing {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          baseOffset = 0
        }
      }
    }
    .overlay {
      if isDeleting {
        ZStack {
          theme.surfaceColor.opacity(0.6)
          ProgressView()
            .tint(.white)
        }
      }
    }
    .allowsHitTesting(!isDeleting)
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

// MARK: - ShimmerModifier

private struct ShimmerModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    if reduceMotion {
      content
        .phaseAnimator([false, true]) { view, phase in
          view.opacity(phase ? 0.6 : 1.0)
        } animation: { _ in
          .easeInOut(duration: 1.2)
        }
    } else {
      content
        .phaseAnimator([false, true]) { view, phase in
          view
            .mask {
              LinearGradient(
                colors: [
                  .white.opacity(0.4),
                  .white,
                  .white.opacity(0.4),
                ],
                startPoint: phase ? .init(x: -0.5, y: 0.5) : .init(x: -1, y: 0.5),
                endPoint: phase ? .init(x: 1.5, y: 0.5) : .init(x: 0, y: 0.5)
              )
            }
        } animation: { _ in
          .linear(duration: 1.5)
        }
    }
  }
}
