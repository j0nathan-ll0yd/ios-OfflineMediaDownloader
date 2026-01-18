import SwiftUI
import ComposableArchitecture
import AVKit

// MARK: - DefaultFilesFeature

@Reducer
struct DefaultFilesFeature {
  @ObservableState
  struct State: Equatable {
    var isLoadingFile: Bool = true
    var file: File?
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var isDownloaded: Bool = false
    var showBenefits: Bool = false
    var isPlaying: Bool = false
    /// Shows loading overlay immediately when play is tapped
    var isPreparingToPlay: Bool = false
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action {
    case onAppear
    case fileLoaded(File?)
    case fileFetchFailed(String)
    /// Called by parent when it has already fetched files - avoids duplicate API call
    case parentProvidedFile(File?)
    case downloadButtonTapped
    case playButtonTapped
    case downloadProgress(Int)
    case downloadCompleted(URL)
    case downloadFailed(String)
    case registerButtonTapped
    case toggleBenefits
    case setPlaying(Bool)
    case alert(PresentationAction<Alert>)

    @CasePathable
    enum Alert: Equatable {
      case dismiss
    }
  }

  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  private enum CancelID { case download }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Don't fetch here - parent (FileListFeature) will provide the file
        // via parentProvidedFile action to avoid duplicate API calls.
        // Just mark as loading until parent provides data.
        guard state.file == nil else { return .none }
        state.isLoadingFile = true
        return .none

      case let .parentProvidedFile(file):
        // Parent has fetched files and is sharing with us
        state.isLoadingFile = false
        state.file = file
        // Check if already downloaded
        if let url = file?.url, fileClient.fileExists(url) {
          state.isDownloaded = true
        }
        return .none

      case let .fileLoaded(file):
        state.isLoadingFile = false
        state.file = file
        // Check if already downloaded
        if let url = file?.url, fileClient.fileExists(url) {
          state.isDownloaded = true
        }
        return .none

      case let .fileFetchFailed(message):
        state.isLoadingFile = false
        state.alert = AlertState {
          TextState("Failed to Load")
        } actions: {
          ButtonState(action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(message)
        }
        return .none

      case .downloadButtonTapped:
        guard let file = state.file, let url = file.url else { return .none }

        // Check if already downloaded
        if fileClient.fileExists(url) {
          state.isDownloaded = true
          return .none
        }

        state.isDownloading = true
        state.downloadProgress = 0
        let fileSize = Int64(file.size ?? 0)
        return .run { send in
          let stream = downloadClient.downloadFile(url, fileSize)
          for await progress in stream {
            switch progress {
            case let .progress(percent):
              await send(.downloadProgress(percent))
            case let .completed(localURL):
              await send(.downloadCompleted(localURL))
            case let .failed(message):
              await send(.downloadFailed(message))
            }
          }
        }
        .cancellable(id: CancelID.download)

      case let .downloadProgress(percent):
        state.downloadProgress = Double(percent) / 100.0
        return .none

      case .downloadCompleted:
        state.isDownloading = false
        state.isDownloaded = true
        return .none

      case let .downloadFailed(message):
        state.isDownloading = false
        state.alert = AlertState {
          TextState("Download Failed")
        } actions: {
          ButtonState(action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(message)
        }
        return .none

      case .playButtonTapped:
        state.isPreparingToPlay = true
        // Delay showing fullScreenCover slightly so loading overlay renders first
        return .run { send in
          try? await Task.sleep(for: .milliseconds(50))
          await send(.setPlaying(true))
        }

      case let .setPlaying(isPlaying):
        state.isPlaying = isPlaying
        if !isPlaying {
          state.isPreparingToPlay = false
          return .none
        }
        // Increment play count when starting playback
        return .run { [coreDataClient] _ in
          try? await coreDataClient.incrementPlayCount()
        }

      case .registerButtonTapped:
        // Handled by parent
        return .none

      case .toggleBenefits:
        state.showBenefits.toggle()
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
