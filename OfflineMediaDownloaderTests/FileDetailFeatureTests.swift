import ConcurrencyExtras
import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("FileDetailFeature Tests")
struct FileDetailFeatureTests {

  // MARK: - File Existence Tests

  @MainActor
  @Test("onAppear checks file existence and sets downloaded true")
  func onAppearFileExists() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.onAppear)

    await store.receive(\.checkFileExistence) {
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("onAppear checks file existence and sets downloaded false")
  func onAppearFileNotExists() async throws {
    var initialState = FileDetailFeature.State(file: TestData.sampleFile)
    initialState.isDownloaded = true

    let store = TestStore(initialState: initialState) {
      FileDetailFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.onAppear)

    await store.receive(\.checkFileExistence) {
      $0.isDownloaded = false
    }
  }

  @MainActor
  @Test("onAppear with nil URL returns immediately")
  func onAppearNilUrl() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.pendingFile)) {
      FileDetailFeature()
    }

    await store.send(.onAppear)
    // No effects should fire
  }

  // MARK: - Download Tests

  @MainActor
  @Test("downloadButtonTapped starts download with progress updates")
  func downloadWithProgress() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 25))
          continuation.yield(.progress(percent: 50))
          continuation.yield(.progress(percent: 100))
          continuation.yield(.completed(localURL: URL(fileURLWithPath: "/tmp/test.mp4")))
          continuation.finish()
        }
      }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.25 }
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.50 }
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 1.0 }
    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("Download failure resets state and shows alert")
  func downloadFails() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 25))
          continuation.yield(.failed("Network timeout"))
          continuation.finish()
        }
      }
      $0.logger.log = { _, _, _, _, _, _ in }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.25 }
    await store.receive(\.downloadFailed) {
      $0.isDownloading = false
      $0.downloadProgress = 0
      $0.alert = AlertState {
        TextState("Download Failed")
      } actions: {
        ButtonState(action: .retryDownload) {
          TextState("Retry")
        }
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Failed to download \"Test Video.mp4\": Network timeout")
      }
    }
  }

  @MainActor
  @Test("Download failure retry triggers download")
  func downloadFailureRetry() async throws {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.alert = AlertState {
      TextState("Download Failed")
    } actions: {
      ButtonState(action: .retryDownload) {
        TextState("Retry")
      }
    }

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.completed(localURL: URL(fileURLWithPath: "/tmp/test.mp4")))
          continuation.finish()
        }
      }
    }

    await store.send(.alert(.presented(.retryDownload))) {
      $0.alert = nil
    }

    await store.receive(\.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.downloadProgress = 1.0
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("downloadButtonTapped does nothing without URL")
  func downloadWithoutUrl() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.pendingFile)) {
      FileDetailFeature()
    }

    await store.send(.downloadButtonTapped)
    // No state changes expected
  }

  // MARK: - Cancel Download Tests

  @MainActor
  @Test("Cancel download stops and resets state")
  func cancelDownload() async throws {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloading = true
    state.downloadProgress = 0.5

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.cancelDownload = { _ in }
    }

    await store.send(.cancelDownloadButtonTapped) {
      $0.isDownloading = false
      $0.downloadProgress = 0
    }
  }

  @MainActor
  @Test("Cancel download with nil URL still cancels")
  func cancelDownloadNilUrl() async throws {
    var state = FileDetailFeature.State(file: TestData.pendingFile)
    state.isDownloading = true
    state.downloadProgress = 0.5

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.cancelDownloadButtonTapped) {
      $0.isDownloading = false
      $0.downloadProgress = 0
    }
  }

  // MARK: - Progress Update Tests

  @MainActor
  @Test("Download progress updates correctly")
  func downloadProgressUpdates() async throws {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloading = true

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.downloadProgressUpdated(0.5)) {
      $0.downloadProgress = 0.5
    }

    await store.send(.downloadProgressUpdated(0.75)) {
      $0.downloadProgress = 0.75
    }
  }

  // MARK: - Download Completed Tests

  @MainActor
  @Test("Download completed sets isDownloaded and progress to 1.0")
  func downloadCompleted() async throws {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloading = true
    state.downloadProgress = 0.9

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.downloadCompleted(URL(fileURLWithPath: "/tmp/test.mp4"))) {
      $0.isDownloading = false
      $0.downloadProgress = 1.0
      $0.isDownloaded = true
    }
  }

  // MARK: - Play Tests

  @MainActor
  @Test("playButtonTapped sends delegate action")
  func playButtonTapped() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    }

    await store.send(.playButtonTapped)
    await store.receive(\.delegate.playFile)
  }

  // MARK: - Delete Tests

  @MainActor
  @Test("deleteButtonTapped shows confirmation alert")
  func deleteButtonTappedShowsAlert() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    }

    await store.send(.deleteButtonTapped) {
      $0.alert = AlertState {
        TextState("Delete File?")
      } actions: {
        ButtonState(role: .destructive, action: .confirmDelete) {
          TextState("Delete")
        }
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("Cancel")
        }
      } message: {
        TextState("Are you sure you want to delete \"Test Video.mp4\"? This action cannot be undone.")
      }
    }
  }

  @MainActor
  @Test("confirmDelete removes file from CoreData and filesystem")
  func confirmDelete() async throws {
    let coreDataDeleteCalled = LockIsolated(false)
    let fileDeleteCalled = LockIsolated(false)

    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.alert = AlertState {
      TextState("Delete File?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmDelete) {
        TextState("Delete")
      }
    }

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in coreDataDeleteCalled.setValue(true) }
      $0.fileClient.fileExists = { _ in true }
      $0.fileClient.deleteFile = { _ in fileDeleteCalled.setValue(true) }
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.alert = nil
    }

    await store.receive(\.delegate.fileDeleted)

    #expect(coreDataDeleteCalled.value == true)
    #expect(fileDeleteCalled.value == true)
  }

  @MainActor
  @Test("confirmDelete skips local file deletion if file not exists")
  func confirmDeleteFileNotExists() async throws {
    let fileDeleteCalled = LockIsolated(false)

    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.alert = AlertState {
      TextState("Delete File?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmDelete) {
        TextState("Delete")
      }
    }

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.fileClient.deleteFile = { _ in fileDeleteCalled.setValue(true) }
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.alert = nil
    }

    await store.receive(\.delegate.fileDeleted)

    #expect(fileDeleteCalled.value == false)
  }

  // MARK: - Share Tests

  @MainActor
  @Test("shareButtonTapped triggers delegate with local URL")
  func shareButtonTapped() async throws {
    let expectedLocalURL = URL(fileURLWithPath: "/local/path/test.mp4")

    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.fileClient.filePath = { _ in expectedLocalURL }
    }

    await store.send(.shareButtonTapped)
    await store.receive(\.delegate.shareFile)
  }

  @MainActor
  @Test("shareButtonTapped does nothing without URL")
  func shareButtonTappedNoUrl() async throws {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.pendingFile)) {
      FileDetailFeature()
    }

    await store.send(.shareButtonTapped)
    // No effects expected
  }

  // MARK: - Alert Tests

  @MainActor
  @Test("alert dismiss clears alert state")
  func alertDismiss() async throws {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.alert = AlertState {
      TextState("Test Alert")
    } actions: {
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.alert(.presented(.dismiss))) {
      $0.alert = nil
    }
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has correct defaults")
  func initialState() async throws {
    let state = FileDetailFeature.State(file: TestData.sampleFile)

    #expect(state.file == TestData.sampleFile)
    #expect(state.isDownloaded == false)
    #expect(state.isDownloading == false)
    #expect(state.downloadProgress == 0)
    #expect(state.alert == nil)
  }
}
