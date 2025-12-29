import ComposableArchitecture
import Foundation

/// Shared download state that can be embedded in features
struct DownloadState: Equatable {
  var isDownloading: Bool = false
  var downloadProgress: Double = 0
  var isDownloaded: Bool = false
}

/// Shared download actions that can be embedded in features
@CasePathable
enum DownloadAction: Equatable {
  case checkFileExistence(Bool)
  case downloadButtonTapped
  case cancelDownloadButtonTapped
  case downloadProgressUpdated(Double)
  case downloadCompleted(URL)
  case downloadFailed(String)
}

/// Shared download alert actions
@CasePathable
enum DownloadAlertAction: Equatable {
  case retryDownload
  case dismiss
}

/// Helper struct for creating download-related effects and reducing boilerplate
enum DownloadBehavior {
  /// Check if a file exists at the given URL
  /// - Parameters:
  ///   - url: The remote URL of the file
  ///   - fileClient: The file client dependency
  /// - Returns: An effect that sends a checkFileExistence action
  @MainActor
  static func checkFileExists(
    url: URL?,
    fileClient: FileClient
  ) -> Effect<DownloadAction> {
    guard let url = url else { return .none }
    return .run { send in
      let exists = fileClient.fileExists(url)
      await send(.checkFileExistence(exists))
    }
  }

  /// Start downloading a file
  /// - Parameters:
  ///   - url: The remote URL to download
  ///   - expectedSize: Expected size in bytes
  ///   - downloadClient: The download client dependency
  ///   - cancelId: The cancel ID for the download task
  /// - Returns: An effect that streams download progress
  @MainActor
  static func startDownload(
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

  /// Cancel an ongoing download
  /// - Parameters:
  ///   - url: The URL being downloaded
  ///   - downloadClient: The download client dependency
  ///   - cancelId: The cancel ID to cancel
  /// - Returns: An effect that cancels the download
  @MainActor
  static func cancelDownload(
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

  /// Create a download failed alert state
  /// - Parameters:
  ///   - fileName: Name of the file that failed
  ///   - message: Error message
  /// - Returns: An AlertState for the download failure
  static func failedAlert(fileName: String, message: String) -> AlertState<DownloadAlertAction> {
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

  /// Reduce download state based on download actions
  /// - Parameters:
  ///   - state: The current download state (inout)
  ///   - action: The download action to handle
  /// - Returns: Whether the action was handled (true) or should be passed through (false)
  static func reduce(state: inout DownloadState, action: DownloadAction) -> Bool {
    switch action {
    case let .checkFileExistence(exists):
      state.isDownloaded = exists
      return true

    case .downloadButtonTapped:
      state.isDownloading = true
      state.downloadProgress = 0
      return false  // Caller should create the download effect

    case .cancelDownloadButtonTapped:
      state.isDownloading = false
      state.downloadProgress = 0
      return false  // Caller should cancel the download

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
      return false  // Caller should show alert
    }
  }
}
