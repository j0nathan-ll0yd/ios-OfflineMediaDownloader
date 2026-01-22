import ComposableArchitecture
import Foundation

@Reducer
struct FileDetailFeature {
  @ObservableState
  struct State: Equatable {
    var file: File
    var isDownloaded: Bool = false
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action {
    case onAppear
    case checkFileExistence(Bool)
    case downloadButtonTapped
    case cancelDownloadButtonTapped
    case playButtonTapped
    case deleteButtonTapped
    case shareButtonTapped
    case downloadProgressUpdated(Double)
    case downloadCompleted(URL)
    case downloadFailed(String)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    @CasePathable
    enum Alert: Equatable {
      case retryDownload
      case confirmDelete
      case dismiss
    }

    @CasePathable
    enum Delegate: Equatable {
      case playFile(File)
      case fileDeleted(File)
      case shareFile(URL)
    }
  }

  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.logger) var logger

  private enum CancelID { case download }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        guard let url = state.file.url else { return .none }
        return .run { [fileClient] send in
          let exists = fileClient.fileExists(url)
          await send(.checkFileExistence(exists))
        }

      case let .checkFileExistence(exists):
        state.isDownloaded = exists
        return .none

      case .downloadButtonTapped:
        guard let remoteURL = state.file.url else { return .none }
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
        state.isDownloaded = true
        let fileId = state.file.fileId
        return .run { [coreDataClient] _ in
          try? await coreDataClient.markFileDownloaded(fileId)
        }

      case let .downloadFailed(message):
        logger.error(.download, "Download failed", metadata: ["file": state.file.key, "error": message])
        state.isDownloading = false
        state.downloadProgress = 0
        let fileName = state.file.title ?? state.file.key
        state.alert = AlertState {
          TextState("Download Failed")
        } actions: {
          ButtonState(action: .retryDownload) {
            TextState("Retry")
          }
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState("Failed to download \"\(fileName)\": \(message)")
        }
        return .none

      case .playButtonTapped:
        return .send(.delegate(.playFile(state.file)))

      case .deleteButtonTapped:
        let fileName = state.file.title ?? state.file.key
        state.alert = AlertState {
          TextState("Delete File?")
        } actions: {
          ButtonState(role: .destructive, action: .confirmDelete) {
            TextState("Delete")
          }
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("Cancel")
          }
        } message: {
          TextState("Are you sure you want to delete \"\(fileName)\"? This action cannot be undone.")
        }
        return .none

      case .shareButtonTapped:
        // Get the local file path and trigger share delegate
        guard let remoteURL = state.file.url else { return .none }
        return .run { [fileClient] send in
          let localURL = fileClient.filePath(remoteURL)
          await send(.delegate(.shareFile(localURL)))
        }

      case .alert(.presented(.retryDownload)):
        return .send(.downloadButtonTapped)

      case .alert(.presented(.confirmDelete)):
        let file = state.file
        return .run { send in
          try await coreDataClient.deleteFile(file)
          if let url = file.url, fileClient.fileExists(url) {
            try await fileClient.deleteFile(url)
          }
          await send(.delegate(.fileDeleted(file)))
        }

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
