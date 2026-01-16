import ComposableArchitecture
import Foundation
import UIKit

@Reducer
struct FileListFeature {
  @ObservableState
  struct State: Equatable {
    var files: IdentifiedArrayOf<FileCellFeature.State> = []
    var pendingFileIds: [String] = []
    var isLoading: Bool = false
    var isAuthenticated: Bool = false
    @Presents var alert: AlertState<Action.Alert>?
    @Presents var selectedFile: FileDetailFeature.State?
    var showAddConfirmation: Bool = false
    var playingFile: File?
    /// Shows loading overlay immediately when play is tapped (before player sheet appears)
    var isPreparingToPlay: Bool = false
    /// Stores the pending URL for retry actions
    var pendingAddUrl: URL?
    /// URL to share via activity sheet
    var sharingFileURL: URL?
    /// Child feature for unauthenticated users to preview default files
    var defaultFiles: DefaultFilesFeature.State = DefaultFilesFeature.State()
  }

  enum Action {
    case onAppear
    case refreshButtonTapped
    case addButtonTapped
    case addFromClipboard
    case confirmationDismissed
    case showError(AppError)
    case addPendingFileId(String)
    case localFilesLoaded([File])
    case remoteFilesResponse(Result<FileResponse, Error>)
    case addFileResponse(Result<DownloadFileResponse, Error>)
    case files(IdentifiedActionOf<FileCellFeature>)
    case deleteFiles(IndexSet)
    case dismissPlayer
    case startPlayer(File)
    case dismissShareSheet
    case alert(PresentationAction<Alert>)
    case detail(PresentationAction<FileDetailFeature.Action>)
    case fileTapped(FileCellFeature.State)
    // Child feature for unauthenticated users
    case defaultFiles(DefaultFilesFeature.Action)
    // Push notification actions
    case fileAddedFromPush(File)
    case updateFileUrl(fileId: String, url: URL)
    case refreshFileState(String)  // fileId
    case fileFailed(fileId: String, error: String)
    case clearAllFiles  // Clears state and CoreData (used on registration)
    case delegate(Delegate)

    @CasePathable
    enum Alert: Equatable {
      case retryRefresh
      case retryAddFile
      case dismiss
    }

    @CasePathable
    enum Delegate: Equatable {
      case authenticationRequired
      case loginRequired
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Load cached files immediately for instant display
        // For unauthenticated users, also fetch from server automatically
        // so they see default files on first launch
        let shouldAutoRefresh = !state.isAuthenticated
        return .run { send in
          let files = try await coreDataClient.getFiles()
          await send(.localFilesLoaded(files))
          if shouldAutoRefresh {
            await send(.refreshButtonTapped)
          }
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

      case .clearAllFiles:
        // Clear in-memory state and CoreData/downloaded files
        state.files = []
        state.pendingFileIds = []
        return .run { _ in
          try await coreDataClient.truncateFiles()
        }

      case .refreshButtonTapped:
        state.isLoading = true
        return .run { send in
          await send(.remoteFilesResponse(Result {
            try await serverClient.getFiles(.all)
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
        let appError = AppError.from(error)
        // Check if this is an auth error - redirect to login
        if appError.requiresReauth {
          return .send(.delegate(.authenticationRequired))
        }
        return .send(.showError(appError))

      case .addButtonTapped:
        // Adding files requires authentication
        if state.isAuthenticated {
          state.showAddConfirmation = true
        } else {
          return .send(.delegate(.loginRequired))
        }
        return .none

      case .confirmationDismissed:
        state.showAddConfirmation = false
        return .none

      case let .showError(appError):
        // Build alert with optional retry button
        if appError.isRetryable {
          state.alert = AlertState {
            TextState(appError.title)
          } actions: {
            ButtonState(action: .retryRefresh) {
              TextState("Retry")
            }
            ButtonState(role: .cancel, action: .dismiss) {
              TextState("OK")
            }
          } message: {
            TextState(appError.message)
          }
        } else {
          state.alert = AlertState {
            TextState(appError.title)
          } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
              TextState("OK")
            }
          } message: {
            TextState(appError.message)
          }
        }
        return .none

      case .alert(.presented(.retryRefresh)):
        return .send(.refreshButtonTapped)

      case .alert(.presented(.retryAddFile)):
        guard let url = state.pendingAddUrl else { return .none }
        return .run { send in
          await send(.addFileResponse(Result {
            try await serverClient.addFile(url: url)
          }))
        }

      case .alert:
        return .none

      case let .addPendingFileId(fileId):
        state.pendingFileIds.append(fileId)
        // Start Live Activity immediately while app is in foreground
        return .run { _ in
          await LiveActivityManager.shared.startActivityWithId(fileId: fileId)
        }

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
            await send(.showError(.invalidClipboardUrl))
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
        state.pendingAddUrl = nil
        return .none

      case let .addFileResponse(.failure(error)):
        let appError = AppError.from(error)
        // Check if this is an auth error - redirect to login
        if appError.requiresReauth {
          return .send(.delegate(.authenticationRequired))
        }
        return .send(.showError(appError))

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
        state.isPreparingToPlay = true
        // Delay showing fullScreenCover slightly so loading overlay renders first
        return .run { send in
          try? await Task.sleep(for: .milliseconds(50))
          await send(.startPlayer(file))
        }

      case let .startPlayer(file):
        state.playingFile = file
        return .run { [coreDataClient] _ in
          try? await coreDataClient.incrementPlayCount()
        }

      case .dismissPlayer:
        state.playingFile = nil
        state.isPreparingToPlay = false
        return .none

      case .dismissShareSheet:
        state.sharingFileURL = nil
        return .none

      // MARK: - Push Notification Actions
      case let .fileAddedFromPush(file):
        // Add or update file in the list
        let isNewFile = state.files[id: file.fileId] == nil
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
        // For new files, trigger onAppear to check download status
        // (handles case where metadata notification was missed but file was downloaded)
        if isNewFile {
          return .send(.files(.element(id: file.fileId, action: .onAppear)))
        }
        return .none

      case let .updateFileUrl(fileId, url):
        // Update the file's URL in state (called when download-ready notification arrives)
        if var fileState = state.files[id: fileId] {
          fileState.file.url = url
          state.files[id: fileId] = fileState
        }
        return .none

      case let .refreshFileState(fileId):
        // If file exists in state, trigger onAppear to re-check download status
        if state.files[id: fileId] != nil {
          return .send(.files(.element(id: fileId, action: .onAppear)))
        }
        // File not in state (metadata notification was missed) - load from CoreData
        return .run { send in
          if let file = try await coreDataClient.getFile(fileId) {
            await send(.fileAddedFromPush(file))
          }
        }

      case let .fileFailed(fileId, error):
        // Update file state to show error
        if var fileState = state.files[id: fileId] {
          fileState.file.status = .failed
          state.files[id: fileId] = fileState
        }
        // Show error alert to user
        state.alert = AlertState {
          TextState("Download Failed")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(error)
        }
        return .none

      case let .fileTapped(fileState):
        // Navigate to file detail view
        state.selectedFile = FileDetailFeature.State(
          file: fileState.file,
          isDownloaded: fileState.isDownloaded,
          isDownloading: fileState.isDownloading,
          downloadProgress: fileState.downloadProgress
        )
        return .none

      // Handle delegate actions from FileDetailFeature
      case let .detail(.presented(.delegate(.fileDeleted(file)))):
        state.files.remove(id: file.fileId)
        state.selectedFile = nil
        return .none

      case let .detail(.presented(.delegate(.playFile(file)))):
        state.isPreparingToPlay = true
        // Delay showing fullScreenCover slightly so loading overlay renders first
        return .run { send in
          try? await Task.sleep(for: .milliseconds(50))
          await send(.startPlayer(file))
        }

      case let .detail(.presented(.delegate(.shareFile(url)))):
        state.sharingFileURL = url
        return .none

      case .detail:
        return .none

      case .files:
        return .none

      case .defaultFiles:
        return .none
      }
    }
    Scope(state: \.defaultFiles, action: \.defaultFiles) {
      DefaultFilesFeature()
    }
    .ifLet(\.$selectedFile, action: \.detail) {
      FileDetailFeature()
    }
    .forEach(\.files, action: \.files) {
      FileCellFeature()
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
