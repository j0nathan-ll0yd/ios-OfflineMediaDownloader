import ComposableArchitecture
import Foundation
import SharedModels
import FileClient
import DownloadClient

/// Shared download state that can be embedded in features
public struct DownloadState: Equatable, Sendable {
  public var isDownloading: Bool = false
  public var downloadProgress: Double = 0
  public var isDownloaded: Bool = false

  public init(isDownloading: Bool = false, downloadProgress: Double = 0, isDownloaded: Bool = false) {
    self.isDownloading = isDownloading
    self.downloadProgress = downloadProgress
    self.isDownloaded = isDownloaded
  }
}

/// Shared download actions that can be embedded in features
@CasePathable
public enum DownloadAction: Equatable, Sendable {
  case checkFileExistence(Bool)
  case downloadButtonTapped
  case cancelDownloadButtonTapped
  case downloadProgressUpdated(Double)
  case downloadCompleted(URL)
  case downloadFailed(String)
}

/// Shared download alert actions
@CasePathable
public enum DownloadAlertAction: Equatable, Sendable {
  case retryDownload
  case dismiss
}

/// Helper struct for creating download-related effects and reducing boilerplate
public enum DownloadBehavior {
  @MainActor
  public static func checkFileExists(
    url: URL?,
    fileClient: FileClient
  ) -> Effect<DownloadAction> {
    guard let url = url else { return .none }
    return .run { send in
      let exists = fileClient.fileExists(url)
      await send(.checkFileExistence(exists))
    }
  }

  @MainActor
  public static func startDownload(
    url: URL,
    expectedSize: Int64,
    downloadClient: DownloadClient,
    cancelId: some Hashable & Sendable
  ) -> Effect<DownloadAction> {
    .run { send in
      let stream = downloadClient.downloadFile(url, expectedSize)
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
    .cancellable(id: cancelId, cancelInFlight: true)
  }

  @MainActor
  public static func cancelDownload(
    url: URL?,
    downloadClient: DownloadClient,
    cancelId: some Hashable & Sendable
  ) -> Effect<DownloadAction> {
    guard let url = url else { return .cancel(id: cancelId) }
    return .run { _ in
      await downloadClient.cancelDownload(url)
    }
    .merge(with: .cancel(id: cancelId))
  }

  public static func failedAlert(fileName: String, message: String) -> AlertState<DownloadAlertAction> {
    AlertState {
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
  }

  public static func reduce(state: inout DownloadState, action: DownloadAction) -> Bool {
    switch action {
    case let .checkFileExistence(exists):
      state.isDownloaded = exists
      return true

    case .downloadButtonTapped:
      state.isDownloading = true
      state.downloadProgress = 0
      return false

    case .cancelDownloadButtonTapped:
      state.isDownloading = false
      state.downloadProgress = 0
      return false

    case let .downloadProgressUpdated(progress):
      state.downloadProgress = progress
      return true

    case .downloadCompleted:
      state.isDownloading = false
      state.downloadProgress = 1.0
      state.isDownloaded = true
      return true

    case .downloadFailed:
      state.isDownloading = false
      state.downloadProgress = 0
      return false
    }
  }
}
