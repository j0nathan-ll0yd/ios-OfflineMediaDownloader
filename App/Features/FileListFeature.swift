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
    @Presents var alert: AlertState<Action.Alert>?
    var showAddConfirmation: Bool = false
    var playingFile: File?
    /// Stores the pending URL for retry actions
    var pendingAddUrl: URL?
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
    case alert(PresentationAction<Alert>)
    // Push notification actions
    case fileAddedFromPush(File)
    case updateFileUrl(fileId: String, url: URL)
    case refreshFileState(String)  // fileId
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
        let appError = AppError.from(error)
        // Check if this is an auth error - redirect to login
        if appError.requiresReauth {
          return .send(.delegate(.authenticationRequired))
        }
        return .send(.showError(appError))

      case .addButtonTapped:
        state.showAddConfirmation = true
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
    .ifLet(\.$alert, action: \.alert)
  }
}
