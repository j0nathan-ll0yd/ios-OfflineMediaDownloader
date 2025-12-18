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
    var showDeleteConfirmation: Bool = false
    var isDeleting: Bool = false

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
    case confirmDelete
    case cancelDelete
    case deleteResponse(Result<Void, Error>)
    case downloadProgressUpdated(Double)
    case downloadCompleted(URL)
    case downloadFailed(String)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case fileDeleted(File)
      case playFile(File)
      case deleteFailed(String)
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
        state.showDeleteConfirmation = true
        return .none

      case .confirmDelete:
        state.showDeleteConfirmation = false
        state.isDeleting = true
        let file = state.file
        return .run { send in
          await send(.deleteResponse(Result {
            // 1. Delete from server
            try await serverClient.deleteFile(file.fileId)
            // 2. Delete local file if downloaded
            if let url = file.url, fileClient.fileExists(url) {
              try await fileClient.deleteFile(url)
            }
            // 3. Delete from CoreData
            try await coreDataClient.deleteFile(file)
          }))
        }

      case .cancelDelete:
        state.showDeleteConfirmation = false
        return .none

      case .deleteResponse(.success):
        state.isDeleting = false
        return .send(.delegate(.fileDeleted(state.file)))

      case let .deleteResponse(.failure(error)):
        state.isDeleting = false
        print("❌ File deletion failed: \(error.localizedDescription)")
        return .send(.delegate(.deleteFailed(error.localizedDescription)))

      case .delegate:
        return .none
      }
    }
  }
}
