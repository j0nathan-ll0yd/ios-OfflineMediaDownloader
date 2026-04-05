import ComposableArchitecture
import DownloadClient
import FileClient
import PersistenceClient
import ServerClient
import SharedModels
import SwiftUI

@Reducer
public struct DefaultFilesFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var isLoadingFile: Bool = true
    public var file: File?
    public var isDownloading: Bool = false
    public var downloadProgress: Double = 0
    public var isDownloaded: Bool = false
    public var showBenefits: Bool = false
    public var isPlaying: Bool = false
    public var isPreparingToPlay: Bool = false
    @Presents public var alert: AlertState<Action.Alert>?

    public init() {}
  }

  public enum Action {
    case onAppear
    case fileLoaded(File?)
    case fileFetchFailed(String)
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
    public enum Alert: Equatable {
      case dismiss
    }
  }

  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  private enum CancelID { case download }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        guard state.file == nil else { return .none }
        state.isLoadingFile = true
        return .none

      case let .parentProvidedFile(file):
        state.isLoadingFile = false
        state.file = file
        if let url = file?.url, fileClient.fileExists(url) {
          state.isDownloaded = true
        }
        return .none

      case let .fileLoaded(file):
        state.isLoadingFile = false
        state.file = file
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
        return .run { [coreDataClient] _ in
          try? await coreDataClient.incrementPlayCount()
        }

      case .registerButtonTapped:
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
