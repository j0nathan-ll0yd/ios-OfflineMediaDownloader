import ComposableArchitecture
import Foundation

@Reducer
struct FileCellFeature {
  @ObservableState
  struct State: Equatable, Identifiable {
    var file: File
    var id: String { file.fileId }
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var isDownloaded: Bool = false  // Cached to avoid fileClient.fileExists() in view body
    @Presents var alert: AlertState<Action.Alert>?

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
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    @CasePathable
    enum Alert: Equatable {
      case retryDownload
      case dismiss
    }

    @CasePathable
    enum Delegate: Equatable {
      case fileDeleted(File)
      case playFile(File)
      // Download tracking delegates for in-app progress banner
      case downloadStarted(File)
      case downloadProgressUpdated(fileId: String, percent: Int)
      case downloadCompleted(fileId: String)
      case downloadFailed(fileId: String, error: String)
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.logger) var logger

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
        let file = state.file
        let expectedSize = Int64(file.size ?? 0)
        return .merge(
          .send(.delegate(.downloadStarted(file))),
          .run { send in
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
        )

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
        let percent = Int(progress * 100)
        return .send(.delegate(.downloadProgressUpdated(fileId: state.file.fileId, percent: percent)))

      case .downloadCompleted:
        state.isDownloading = false
        state.downloadProgress = 1.0
        state.isDownloaded = true  // Update cached state
        let fileId = state.file.fileId
        return .merge(
          .send(.delegate(.downloadCompleted(fileId: fileId))),
          .run { [coreDataClient] _ in
            try? await coreDataClient.markFileDownloaded(fileId)
          }
        )

      case let .downloadFailed(message):
        logger.error(.download, "Download failed", metadata: ["file": state.file.key, "error": message])
        state.isDownloading = false
        state.downloadProgress = 0
        let fileId = state.file.fileId
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
        return .send(.delegate(.downloadFailed(fileId: fileId, error: message)))

      case .alert(.presented(.retryDownload)):
        return .send(.downloadButtonTapped)

      case .alert:
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
    .ifLet(\.$alert, action: \.alert)
  }
}
