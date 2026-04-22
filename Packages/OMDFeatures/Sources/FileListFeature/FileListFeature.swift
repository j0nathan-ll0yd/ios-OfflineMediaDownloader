import APIClient
import ComposableArchitecture
import DefaultFilesFeature
import FileCellFeature
import FileDetailFeature
import Foundation
import LiveActivityClient
import LoggerClient
import OrderedCollections
import PasteboardClient
import PersistenceClient
import ServerClient
import SharedModels
import ThumbnailCacheClient
import UIKit

@Reducer
public struct FileListFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var files: IdentifiedArrayOf<FileCellFeature.State> = []
    public var pendingFileIds: OrderedSet<String> = []
    public var isLoading: Bool = false
    @Shared(.inMemory("isAuthenticated")) public var isAuthenticated = false
    @Shared(.inMemory("isRegistered")) public var isRegistered = false
    @Presents public var alert: AlertState<Action.Alert>?
    @Presents public var selectedFile: FileDetailFeature.State?
    public var showAddConfirmation: Bool = false
    public var playingFile: File?
    public var isPreparingToPlay: Bool = false
    public var pendingAddUrl: URL?
    public var pendingYoutubeId: String?
    public var sharingFileURL: URL?
    public var defaultFiles: DefaultFilesFeature.State = .init()

    public init() {}
  }

  public enum Action {
    case onAppear
    case refreshButtonTapped
    case addButtonTapped
    case addFromClipboard
    case prepareAddFile(url: URL, youtubeId: String?)
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
    case defaultFiles(DefaultFilesFeature.Action)
    case fileAddedFromPush(File)
    case updateFileUrl(fileId: String, url: URL)
    case fileDownloadStartedOnServer(fileId: String, thumbnailUrl: String?)
    case serverDownloadProgress(fileId: String, percent: Int)
    case refreshFileState(String)
    case fileFailed(fileId: String, error: String)
    case clearAllFiles
    case delegate(Delegate)

    @CasePathable
    public enum Alert: Equatable {
      case retryRefresh
      case retryAddFile
      case dismiss
    }

    @CasePathable
    public enum Delegate: Equatable {
      case authenticationRequired
      case loginRequired
      case downloadStarted(File)
      case downloadProgressUpdated(fileId: String, percent: Int)
      case downloadCompleted(fileId: String)
      case downloadFailed(fileId: String, error: String)
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.logger) var logger
  @Dependency(\.liveActivityClient) var liveActivityClient
  @Dependency(\.pasteboardClient) var pasteboardClient
  @Dependency(\.thumbnailCacheClient) var thumbnailCacheClient

  private enum CancelID {
    case loadFiles
    case addFile
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        let isAuthenticated = state.isAuthenticated
        let isRegistered = state.isRegistered
        logger.debug(.lifecycle, "FileListFeature.onAppear: isAuthenticated=\(isAuthenticated), isRegistered=\(isRegistered)")
        let pasteboard = pasteboardClient
        return .merge(
          .run { send in
            let files = try await coreDataClient.getFiles()
            await send(.localFilesLoaded(files))
            if !isRegistered {
              logger.debug(.lifecycle, "FileListFeature.onAppear: triggering auto-refresh for unregistered guest user")
              await send(.refreshButtonTapped)
            }
          },
          .run { _ in
            _ = pasteboard.hasStrings()
          }
        )

      case let .localFilesLoaded(files):
        let existingStates = Dictionary(uniqueKeysWithValues: state.files.map { ($0.id, $0) })
        let filesToShow = state.isRegistered
          ? files
          : files.filter { $0.fileId != "default" }
        state.files = IdentifiedArray(uniqueElements: filesToShow.map { file in
          var newState = FileCellFeature.State(file: file)
          if let existing = existingStates[file.fileId] {
            newState.isDownloaded = existing.isDownloaded
            newState.isDownloading = existing.isDownloading
            newState.isServerDownloading = existing.isServerDownloading
            newState.downloadProgress = existing.downloadProgress
          }
          return newState
        })
        state.isLoading = false
        let thumbnails = thumbnailsToFetch(from: filesToShow)
        let thumbnailCacheClient = thumbnailCacheClient
        return thumbnails.isEmpty ? .none : .run { _ in
          await thumbnailCacheClient.prefetchThumbnails(thumbnails)
        }

      case .clearAllFiles:
        state.files = []
        state.pendingFileIds = []
        return .run { _ in
          try await coreDataClient.truncateFiles()
        }

      case .refreshButtonTapped:
        if state.isRegistered, !state.isAuthenticated {
          return .send(.delegate(.authenticationRequired))
        }
        state.isLoading = true
        return .run { send in
          await send(.remoteFilesResponse(Result {
            try await serverClient.getFiles(.all)
          }))
        }
        .cancellable(id: CancelID.loadFiles, cancelInFlight: true)

      case let .remoteFilesResponse(.success(response)):
        if let fileList = response.body {
          let existingStates = Dictionary(uniqueKeysWithValues: state.files.map { ($0.id, $0) })
          let filesToShow = state.isRegistered
            ? fileList.contents
            : fileList.contents.filter { $0.fileId != "default" }
          state.files = IdentifiedArray(uniqueElements: filesToShow.map { file in
            var newState = FileCellFeature.State(file: file)
            if let existing = existingStates[file.fileId] {
              newState.isDownloaded = existing.isDownloaded
              newState.isDownloading = existing.isDownloading
              newState.isServerDownloading = existing.isServerDownloading
              newState.downloadProgress = existing.downloadProgress
            }
            return newState
          })
          let availableIds = Set(fileList.contents.map(\.fileId))
          state.pendingFileIds.removeAll { availableIds.contains($0) }
        }
        state.isLoading = false
        let firstFile = response.body?.contents.first
        let isRegistered = state.isRegistered
        let thumbnails = thumbnailsToFetch(from: response.body?.contents ?? [])
        let thumbnailCacheClient = thumbnailCacheClient
        return .merge(
          isRegistered ? .none : .send(.defaultFiles(.parentProvidedFile(firstFile))),
          .run { [files = response.body?.contents ?? []] _ in
            try await coreDataClient.cacheFiles(files)
          },
          thumbnails.isEmpty ? .none : .run { _ in
            await thumbnailCacheClient.prefetchThumbnails(thumbnails)
          }
        )

      case let .remoteFilesResponse(.failure(error)):
        state.isLoading = false
        let appError = AppError.from(error)
        if appError.requiresReauth {
          return .merge(
            .send(.defaultFiles(.fileFetchFailed(appError.message))),
            .send(.delegate(.authenticationRequired))
          )
        }
        return .merge(
          .send(.defaultFiles(.fileFetchFailed(appError.message))),
          .send(.showError(appError))
        )

      case .addButtonTapped:
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

      case .alert(.presented(.dismiss)):
        state.pendingYoutubeId = nil
        state.pendingAddUrl = nil
        return .none

      case .alert:
        return .none

      case let .addPendingFileId(fileId):
        state.pendingFileIds.append(fileId)
        return .run { [liveActivityClient] _ in
          await liveActivityClient.startActivityWithId(fileId: fileId)
        }

      case let .prepareAddFile(url, youtubeId):
        state.pendingAddUrl = url
        state.pendingYoutubeId = youtubeId
        return .none

      case .addFromClipboard:
        state.showAddConfirmation = false
        let pasteboard = pasteboardClient
        return .run { send in
          let result: (URL, String?)? = {
            guard pasteboard.hasStrings(),
                  let urlString = pasteboard.string(),
                  let url = URL(string: urlString)
            else {
              return nil
            }
            return (url, urlString.youtubeID)
          }()

          guard let (url, youtubeId) = result else {
            await send(.showError(.invalidClipboardUrl))
            return
          }

          await send(.prepareAddFile(url: url, youtubeId: youtubeId))

          await send(.addFileResponse(Result {
            try await serverClient.addFile(url: url)
          }))
        }
        .cancellable(id: CancelID.addFile, cancelInFlight: true)

      case .addFileResponse(.success):
        let youtubeId = state.pendingYoutubeId
        state.pendingAddUrl = nil
        state.pendingYoutubeId = nil
        if let youtubeId {
          return .send(.addPendingFileId(youtubeId))
        }
        return .none

      case let .addFileResponse(.failure(error)):
        let appError = AppError.from(error)
        if appError.requiresReauth {
          state.pendingAddUrl = nil
          state.pendingYoutubeId = nil
          return .send(.delegate(.authenticationRequired))
        }
        if appError.isRetryable {
          state.alert = AlertState {
            TextState(appError.title)
          } actions: {
            ButtonState(action: .retryAddFile) {
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

      case let .fileAddedFromPush(file):
        let isNewFile = state.files[id: file.fileId] == nil
        if var existing = state.files[id: file.fileId] {
          existing.file = file
          state.files[id: file.fileId] = existing
        } else {
          state.files.append(FileCellFeature.State(file: file))
        }
        state.files.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
        state.pendingFileIds.remove(file.fileId)

        let thumbnailCacheClient = thumbnailCacheClient
        var effects: [Effect<Action>] = []

        if let urlString = file.thumbnailUrl, let url = URL(string: urlString) {
          effects.append(.run { _ in
            await thumbnailCacheClient.prefetchThumbnails([(fileId: file.fileId, url: url)])
          })
        }

        if isNewFile {
          effects.append(.send(.files(.element(id: file.fileId, action: .onAppear))))
        }

        return effects.isEmpty ? .none : .merge(effects)

      case let .updateFileUrl(fileId, url):
        if var fileState = state.files[id: fileId] {
          fileState.file.url = url
          fileState.isServerDownloading = false
          state.files[id: fileId] = fileState
        }
        return .none

      case let .fileDownloadStartedOnServer(fileId, thumbnailUrl):
        if var fileState = state.files[id: fileId] {
          fileState.isServerDownloading = true
          if let thumbnailUrl {
            fileState.file.thumbnailUrl = thumbnailUrl
          }
          state.files[id: fileId] = fileState
        }
        return .none

      case let .serverDownloadProgress(fileId, percent):
        let liveActivityClient = liveActivityClient
        return .run { _ in
          await liveActivityClient.updateProgress(fileId, percent, .serverDownloading)
        }

      case let .refreshFileState(fileId):
        if state.files[id: fileId] != nil {
          return .send(.files(.element(id: fileId, action: .onAppear)))
        }
        return .run { send in
          if let file = try await coreDataClient.getFile(fileId) {
            await send(.fileAddedFromPush(file))
          }
        }

      case let .fileFailed(fileId, error):
        state.pendingFileIds.remove(fileId)
        if var fileState = state.files[id: fileId] {
          fileState.file.status = .failed
          state.files[id: fileId] = fileState
        }
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
        state.selectedFile = FileDetailFeature.State(
          file: fileState.file,
          isDownloaded: fileState.isDownloaded,
          isDownloading: fileState.isDownloading,
          downloadProgress: fileState.downloadProgress
        )
        return .none

      case let .detail(.presented(.delegate(.fileDeleted(file)))):
        state.files.remove(id: file.fileId)
        state.selectedFile = nil
        return .none

      case let .detail(.presented(.delegate(.playFile(file)))):
        state.isPreparingToPlay = true
        return .run { send in
          try? await Task.sleep(for: .milliseconds(50))
          await send(.startPlayer(file))
        }

      case let .detail(.presented(.delegate(.shareFile(url)))):
        state.sharingFileURL = url
        return .none

      case .detail:
        return .none

      case let .files(.element(id: _, action: .delegate(.downloadStarted(file)))):
        return .send(.delegate(.downloadStarted(file)))

      case let .files(.element(id: _, action: .delegate(.downloadProgressUpdated(fileId, percent)))):
        return .send(.delegate(.downloadProgressUpdated(fileId: fileId, percent: percent)))

      case let .files(.element(id: _, action: .delegate(.downloadCompleted(fileId)))):
        return .send(.delegate(.downloadCompleted(fileId: fileId)))

      case let .files(.element(id: _, action: .delegate(.downloadFailed(fileId, error)))):
        return .send(.delegate(.downloadFailed(fileId: fileId, error: error)))

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

  // MARK: - Helpers

  private func thumbnailsToFetch(from files: [File]) -> [(fileId: String, url: URL)] {
    files.compactMap { file in
      guard let urlString = file.thumbnailUrl, let url = URL(string: urlString) else { return nil }
      return (fileId: file.fileId, url: url)
    }
  }
}
