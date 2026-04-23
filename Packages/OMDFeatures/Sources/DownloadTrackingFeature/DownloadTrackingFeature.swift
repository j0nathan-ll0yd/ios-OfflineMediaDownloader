import ComposableArchitecture
import DownloadClient
import Foundation
import LiveActivityClient
import LoggerClient
import PersistenceClient
import SharedModels

@Reducer
public struct DownloadTrackingFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public init() {}
  }

  public enum Action {
    case startDownload(fileId: String, title: String, url: URL, size: Int64)
    case downloadCompleted(fileId: String)
    case downloadFailed(fileId: String, error: String)
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable {
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

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case let .startDownload(fileId, title, url, size):
        return .merge(
          .send(.delegate(.downloadStarted(fileId: fileId, title: title, isBackground: true))),
          .run { [logger, downloadClient, liveActivityClient] send in
            logger.info(.download, "Starting background download", metadata: ["fileId": fileId])
            await liveActivityClient.updateProgress(fileId: fileId, percent: 0, status: .downloading)
            let stream = downloadClient.downloadFile(url, size)
            var lastReportedPercent = 0
            for await progress in stream {
              switch progress {
              case .completed:
                await send(.downloadCompleted(fileId: fileId))
              case let .failed(message):
                await send(.downloadFailed(fileId: fileId, error: message))
              case let .progress(percent):
                // Throttle Live Activity and delegate updates to 10% intervals
                if percent >= lastReportedPercent + 10 || percent >= 100 {
                  lastReportedPercent = percent
                  await liveActivityClient.updateProgress(fileId: fileId, percent: percent, status: .downloading)
                  await send(.delegate(.downloadProgressUpdated(fileId: fileId, percent: percent)))
                }
              }
            }
          }
        )

      case let .downloadCompleted(fileId):
        logger.info(.download, "Background download completed", metadata: ["fileId": fileId])
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
        return .merge(
          .run { [liveActivityClient] _ in
            await liveActivityClient.endActivity(fileId: fileId, status: .failed, errorMessage: error)
          },
          .send(.delegate(.downloadFailed(fileId: fileId, error: error)))
        )

        return .none

      case .delegate:
        return .none
      }
    }
  }
}
