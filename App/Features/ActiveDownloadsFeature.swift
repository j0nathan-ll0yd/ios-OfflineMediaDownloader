import ComposableArchitecture
import Foundation

/// Tracks active downloads for in-app progress display.
/// This feature provides visibility into download progress when Live Activities
/// are declined or unavailable.
@Reducer
struct ActiveDownloadsFeature {
  @ObservableState
  struct State: Equatable {
    var activeDownloads: IdentifiedArrayOf<ActiveDownload> = []

    /// Returns true if there are any active (non-completed) downloads
    var hasActiveDownloads: Bool {
      activeDownloads.contains { $0.status == .downloading }
    }

    /// Returns true if there are any visible downloads (including recently completed)
    var hasVisibleDownloads: Bool {
      !activeDownloads.isEmpty
    }
  }

  struct ActiveDownload: Equatable, Identifiable {
    let fileId: String
    var id: String { fileId }
    var title: String
    var progress: Int  // 0-100
    var status: DownloadStatus
    var isBackgroundInitiated: Bool

    enum DownloadStatus: Equatable {
      case downloading
      case completed
      case failed(String)
    }
  }

  enum Action {
    case downloadStarted(fileId: String, title: String, isBackground: Bool)
    case downloadProgressUpdated(fileId: String, percent: Int)
    case downloadCompleted(fileId: String)
    case downloadFailed(fileId: String, error: String)
    case clearCompleted
    case clearAll
    case removeDownload(fileId: String)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .downloadStarted(fileId, title, isBackground):
        // Don't add duplicates
        guard state.activeDownloads[id: fileId] == nil else { return .none }
        state.activeDownloads.append(
          ActiveDownload(
            fileId: fileId,
            title: title,
            progress: 0,
            status: .downloading,
            isBackgroundInitiated: isBackground
          )
        )
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
        // Auto-remove completed downloads after 3 seconds
        return .run { send in
          try? await Task.sleep(for: .seconds(3))
          await send(.removeDownload(fileId: fileId))
        }

      case let .downloadFailed(fileId, error):
        if var download = state.activeDownloads[id: fileId] {
          download.status = .failed(error)
          state.activeDownloads[id: fileId] = download
        }
        // Auto-remove failed downloads after 5 seconds
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
