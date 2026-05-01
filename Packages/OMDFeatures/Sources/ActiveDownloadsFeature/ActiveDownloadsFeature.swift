import ComposableArchitecture
import Foundation
import SharedModels

@Reducer
public struct ActiveDownloadsFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var activeDownloads: IdentifiedArrayOf<ActiveDownload> = []

    public var hasActiveDownloads: Bool {
      activeDownloads.contains {
        switch $0.status {
        case .queued, .serverDownloading, .downloading:
          true
        case .completed, .failed:
          false
        }
      }
    }

    public var hasVisibleDownloads: Bool {
      !activeDownloads.isEmpty
    }

    public init() {}
  }

  public struct ActiveDownload: Equatable, Identifiable, Sendable {
    public let fileId: String
    public var id: String {
      fileId
    }

    public var title: String
    public var progress: Int
    public var status: DownloadStatus
    public var isBackgroundInitiated: Bool

    public enum DownloadStatus: Equatable, Sendable {
      case queued
      case serverDownloading
      case downloading
      case completed
      case failed(String)
    }

    public init(fileId: String, title: String, progress: Int, status: DownloadStatus, isBackgroundInitiated: Bool) {
      self.fileId = fileId
      self.title = title
      self.progress = progress
      self.status = status
      self.isBackgroundInitiated = isBackgroundInitiated
    }
  }

  public enum Action {
    case fileQueued(fileId: String, title: String)
    case serverDownloadStarted(fileId: String)
    case serverDownloadProgressUpdated(fileId: String, percent: Int)
    case downloadStarted(fileId: String, title: String, isBackground: Bool)
    case downloadProgressUpdated(fileId: String, percent: Int)
    case downloadCompleted(fileId: String)
    case downloadFailed(fileId: String, error: String)
    case clearCompleted
    case clearAll
    case removeDownload(fileId: String)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .fileQueued(fileId, title):
        guard state.activeDownloads[id: fileId] == nil else { return .none }
        state.activeDownloads.append(
          ActiveDownload(
            fileId: fileId,
            title: title,
            progress: 0,
            status: .queued,
            isBackgroundInitiated: false
          )
        )
        return .none

      case let .serverDownloadStarted(fileId):
        if var download = state.activeDownloads[id: fileId] {
          download.status = .serverDownloading
          download.progress = 0
          state.activeDownloads[id: fileId] = download
        }
        return .none

      case let .serverDownloadProgressUpdated(fileId, percent):
        if var download = state.activeDownloads[id: fileId] {
          download.status = .serverDownloading
          download.progress = percent
          state.activeDownloads[id: fileId] = download
        }
        return .none

      case let .downloadStarted(fileId, title, isBackground):
        if var download = state.activeDownloads[id: fileId] {
          download.status = .downloading
          download.progress = 0
          download.isBackgroundInitiated = isBackground
          state.activeDownloads[id: fileId] = download
        } else {
          state.activeDownloads.append(
            ActiveDownload(
              fileId: fileId,
              title: title,
              progress: 0,
              status: .downloading,
              isBackgroundInitiated: isBackground
            )
          )
        }
        return .none

      case let .downloadProgressUpdated(fileId, percent):
        if var download = state.activeDownloads[id: fileId] {
          download.progress = percent
          state.activeDownloads[id: fileId] = download
        }
        return .none

      case let .downloadCompleted(fileId):
        if var download = state.activeDownloads[id: fileId] {
          download.progress = 100
          download.status = .completed
          state.activeDownloads[id: fileId] = download
        }
        return .run { send in
          try? await Task.sleep(for: .seconds(3))
          await send(.removeDownload(fileId: fileId))
        }

      case let .downloadFailed(fileId, error):
        if var download = state.activeDownloads[id: fileId] {
          download.status = .failed(error)
          state.activeDownloads[id: fileId] = download
        }
        return .run { send in
          try? await Task.sleep(for: .seconds(5))
          await send(.removeDownload(fileId: fileId))
        }

      case .clearCompleted:
        state.activeDownloads.removeAll { download in
          if case .completed = download.status { return true }
          return false
        }
        return .none

      case .clearAll:
        state.activeDownloads.removeAll()
        return .none

      case let .removeDownload(fileId):
        state.activeDownloads.remove(id: fileId)
        return .none
      }
    }
  }
}
