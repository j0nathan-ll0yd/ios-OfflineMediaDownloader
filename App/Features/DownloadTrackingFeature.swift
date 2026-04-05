import ComposableArchitecture
import Foundation

@Reducer
struct DownloadTrackingFeature {
  @ObservableState
  struct State: Equatable {
    var initiatingDownloads: IdentifiedArrayOf<DownloadInitiation> = []
    var isBlockingForDownloadInitiation: Bool {
      !initiatingDownloads.isEmpty
    }

    struct DownloadInitiation: Equatable, Identifiable {
      var id: String {
        fileId
      }

      let fileId: String
      let title: String
    }
  }

  enum Action {
    case startDownload(fileId: String, title: String, url: URL, size: Int64)
    case downloadCompleted(fileId: String)
    case downloadFailed(fileId: String, error: String)
    case firstProgressReceived(fileId: String)
    case initiationTimeout(fileId: String)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case downloadStarted(fileId: String, title: String, isBackground: Bool)
      case downloadProgressUpdated(fileId: String, percent: Int)
      case downloadCompleted(fileId: String)
      case downloadFailed(fileId: String, error: String)
      case refreshFileState(fileId: String)
    }
  }

  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.liveActivityClient) var liveActivityClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.logger) var logger

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .startDownload(fileId, title, url, size):
        state.initiatingDownloads.append(State.DownloadInitiation(fileId: fileId, title: title))
        return .merge(
          .send(.delegate(.downloadStarted(fileId: fileId, title: title, isBackground: true))),
          .run { [logger, downloadClient, liveActivityClient] send in
            logger.info(.download, "Starting background download", metadata: ["fileId": fileId])
            await liveActivityClient.updateProgress(fileId: fileId, percent: 0, status: .downloading)
            let stream = downloadClient.downloadFile(url, size)
            var firstProgressReceived = false
            for await progress in stream {
              switch progress {
              case .completed:
                await send(.downloadCompleted(fileId: fileId))
              case let .failed(message):
                await send(.downloadFailed(fileId: fileId, error: message))
              case let .progress(percent):
                if !firstProgressReceived {
                  firstProgressReceived = true
                  await send(.firstProgressReceived(fileId: fileId))
                }
                await liveActivityClient.updateProgress(fileId: fileId, percent: percent, status: .downloading)
                await send(.delegate(.downloadProgressUpdated(fileId: fileId, percent: percent)))
              }
            }
          },
          .run { send in
            try? await Task.sleep(for: .seconds(10))
            await send(.initiationTimeout(fileId: fileId))
          }
        )

      case let .downloadCompleted(fileId):
        logger.info(.download, "Background download completed", metadata: ["fileId": fileId])
        state.initiatingDownloads.remove(id: fileId)
        return .merge(
          .run { [coreDataClient, liveActivityClient] send in
            await liveActivityClient.endActivity(fileId: fileId, status: .downloaded, errorMessage: nil)
            try? await coreDataClient.markFileDownloaded(fileId)
            await send(.delegate(.refreshFileState(fileId: fileId)))
          },
          .send(.delegate(.downloadCompleted(fileId: fileId)))
        )

      case let .downloadFailed(fileId, error):
        logger.error(.download, "Background download failed", metadata: ["fileId": fileId, "error": error])
        state.initiatingDownloads.remove(id: fileId)
        return .merge(
          .run { [liveActivityClient] _ in
            await liveActivityClient.endActivity(fileId: fileId, status: .failed, errorMessage: error)
          },
          .send(.delegate(.downloadFailed(fileId: fileId, error: error)))
        )

      case let .firstProgressReceived(fileId):
        state.initiatingDownloads.remove(id: fileId)
        return .none

      case let .initiationTimeout(fileId):
        if state.initiatingDownloads[id: fileId] != nil {
          logger.warning(.download, "Download initiation timed out", metadata: ["fileId": fileId])
          state.initiatingDownloads.remove(id: fileId)
        }
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
