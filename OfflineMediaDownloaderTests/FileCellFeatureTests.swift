import ConcurrencyExtras
import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("FileCellFeature Tests")
struct FileCellFeatureTests {

  // MARK: - File Existence Tests

  @MainActor
  @Test("onAppear checks file existence and sets downloaded true")
  func onAppearFileExists() async throws {
    let store = TestStore(initialState: FileCellFeature.State(file: TestData.sampleFile)) {
      FileCellFeature()
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
    // Start with isDownloaded = true to verify it gets set to false
    var initialState = FileCellFeature.State(file: TestData.sampleFile)
    initialState.isDownloaded = true

    let store = TestStore(initialState: initialState) {
      FileCellFeature()
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
    let store = TestStore(initialState: FileCellFeature.State(file: TestData.pendingFile)) {
      FileCellFeature()
    }

    await store.send(.onAppear)
    // No effects should fire
  }

  // MARK: - Download Tests

  @MainActor
  @Test("Download button starts download with progress updates")
  func downloadWithProgress() async throws {
    let store = TestStore(initialState: FileCellFeature.State(file: TestData.sampleFile)) {
      FileCellFeature()
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

    await store.receive(\.delegate.downloadStarted)
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.25 }
    await store.receive(\.delegate.downloadProgressUpdated)
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.5 }
    await store.receive(\.delegate.downloadProgressUpdated)
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 1.0 }
    await store.receive(\.delegate.downloadProgressUpdated)
    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.isDownloaded = true
    }
    await store.receive(\.delegate.downloadCompleted)
  }

  @MainActor
  @Test("Download failure resets state and shows alert")
  func downloadFails() async throws {
    let store = TestStore(initialState: FileCellFeature.State(file: TestData.sampleFile)) {
      FileCellFeature()
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

    await store.receive(\.delegate.downloadStarted)
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.25 }
    await store.receive(\.delegate.downloadProgressUpdated)
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
    await store.receive(\.delegate.downloadFailed)
  }

  @MainActor
  @Test("Download failure retry triggers download")
  func downloadFailureRetry() async throws {
    var state = FileCellFeature.State(file: TestData.sampleFile)
    state.alert = AlertState {
      TextState("Download Failed")
    } actions: {
      ButtonState(action: .retryDownload) {
        TextState("Retry")
      }
    }

    let store = TestStore(initialState: state) {
      FileCellFeature()
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

    await store.receive(\.delegate.downloadStarted)
    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.downloadProgress = 1.0
      $0.isDownloaded = true
    }
    await store.receive(\.delegate.downloadCompleted)
  }

  @MainActor
  @Test("Cancel download stops and resets state")
  func cancelDownload() async throws {
    var state = FileCellFeature.State(file: TestData.sampleFile)
    state.isDownloading = true
    state.downloadProgress = 0.5

    let store = TestStore(initialState: state) {
      FileCellFeature()
    } withDependencies: {
      $0.downloadClient.cancelDownload = { _ in }
    }

    await store.send(.cancelDownloadButtonTapped) {
      $0.isDownloading = false
      $0.downloadProgress = 0
    }
  }

  @MainActor
  @Test("Download button does nothing without URL")
  func downloadWithoutUrl() async throws {
    let store = TestStore(initialState: FileCellFeature.State(file: TestData.pendingFile)) {
      FileCellFeature()
    }

    await store.send(.downloadButtonTapped)
    // No state changes expected
  }

  @MainActor
  @Test("Download completed sets isDownloaded and progress to 1.0")
  func downloadCompleted() async throws {
    var state = FileCellFeature.State(file: TestData.sampleFile)
    state.isDownloading = true
    state.downloadProgress = 0.9

    let store = TestStore(initialState: state) {
      FileCellFeature()
    }

    await store.send(.downloadCompleted(URL(fileURLWithPath: "/tmp/test.mp4"))) {
      $0.isDownloading = false
      $0.downloadProgress = 1.0
      $0.isDownloaded = true
    }
    await store.receive(\.delegate.downloadCompleted)
  }

  // MARK: - Delete Tests

  @MainActor
  @Test("Delete button triggers file deletion from CoreData, filesystem, and thumbnail cache")
  func deleteRemovesFiles() async throws {
    let coreDataDeleteCalled = LockIsolated(false)
    let fileDeleteCalled = LockIsolated(false)
    let thumbnailDeleteCalled = LockIsolated(false)

    let store = TestStore(initialState: FileCellFeature.State(file: TestData.sampleFile)) {
      FileCellFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in coreDataDeleteCalled.setValue(true) }
      $0.fileClient.fileExists = { _ in true }
      $0.fileClient.deleteFile = { _ in fileDeleteCalled.setValue(true) }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in thumbnailDeleteCalled.setValue(true) }
    }

    await store.send(.deleteButtonTapped)
    await store.receive(\.delegate.fileDeleted)

    #expect(coreDataDeleteCalled.value == true)
    #expect(fileDeleteCalled.value == true)
    #expect(thumbnailDeleteCalled.value == true)
  }

  @MainActor
  @Test("Delete skips local file removal if not exists but still deletes thumbnail")
  func deleteSkipsIfNotExists() async throws {
    let fileDeleteCalled = LockIsolated(false)
    let thumbnailDeleteCalled = LockIsolated(false)

    let store = TestStore(initialState: FileCellFeature.State(file: TestData.sampleFile)) {
      FileCellFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.fileClient.deleteFile = { _ in fileDeleteCalled.setValue(true) }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in thumbnailDeleteCalled.setValue(true) }
    }

    await store.send(.deleteButtonTapped)
    await store.receive(\.delegate.fileDeleted)

    #expect(fileDeleteCalled.value == false)
    #expect(thumbnailDeleteCalled.value == true)
  }

  @MainActor
  @Test("Delete with nil URL still removes from CoreData and thumbnail cache")
  func deleteWithNilUrl() async throws {
    let coreDataDeleteCalled = LockIsolated(false)
    let thumbnailDeleteCalled = LockIsolated(false)

    let store = TestStore(initialState: FileCellFeature.State(file: TestData.pendingFile)) {
      FileCellFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in coreDataDeleteCalled.setValue(true) }
      $0.fileClient.fileExists = { _ in false }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in thumbnailDeleteCalled.setValue(true) }
    }

    await store.send(.deleteButtonTapped)
    await store.receive(\.delegate.fileDeleted)

    #expect(coreDataDeleteCalled.value == true)
    #expect(thumbnailDeleteCalled.value == true)
  }

  // MARK: - Play Tests

  @MainActor
  @Test("Play button sends delegate action")
  func playButtonSendsDelegate() async throws {
    let store = TestStore(initialState: FileCellFeature.State(file: TestData.sampleFile)) {
      FileCellFeature()
    }

    await store.send(.playButtonTapped)
    await store.receive(\.delegate.playFile)
  }

  // MARK: - Pending State Tests

  @MainActor
  @Test("isPending is true when URL is nil")
  func isPendingWhenNoUrl() async throws {
    let state = FileCellFeature.State(file: TestData.pendingFile)
    #expect(state.isPending == true)
  }

  @MainActor
  @Test("isPending is false when URL is present")
  func isNotPendingWhenUrlPresent() async throws {
    let state = FileCellFeature.State(file: TestData.sampleFile)
    #expect(state.isPending == false)
  }

  // MARK: - State ID Tests

  @MainActor
  @Test("State ID matches file ID")
  func stateIdMatchesFileId() async throws {
    let state = FileCellFeature.State(file: TestData.sampleFile)
    #expect(state.id == TestData.sampleFile.fileId)
  }

  // MARK: - Progress Update Tests

  @MainActor
  @Test("Download progress updates correctly")
  func downloadProgressUpdates() async throws {
    var state = FileCellFeature.State(file: TestData.sampleFile)
    state.isDownloading = true

    let store = TestStore(initialState: state) {
      FileCellFeature()
    }

    await store.send(.downloadProgressUpdated(0.5)) {
      $0.downloadProgress = 0.5
    }
    await store.receive(\.delegate.downloadProgressUpdated)

    await store.send(.downloadProgressUpdated(0.75)) {
      $0.downloadProgress = 0.75
    }
    await store.receive(\.delegate.downloadProgressUpdated)
  }
}
