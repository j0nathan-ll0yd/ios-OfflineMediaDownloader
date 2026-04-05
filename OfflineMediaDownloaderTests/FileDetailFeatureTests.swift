import ComposableArchitecture
import ConcurrencyExtras
import Foundation
@testable import OfflineMediaDownloader
import Testing

struct FileDetailFeatureTests {
  // MARK: - onAppear Tests

  @MainActor
  @Test("onAppear checks file existence and sets isDownloaded true")
  func onAppearFileExists() async {
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
  @Test("onAppear checks file existence and sets isDownloaded false")
  func onAppearFileNotExists() async {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloaded = true

    let store = TestStore(initialState: state) {
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
  @Test("onAppear with no URL does nothing")
  func onAppearWithNoUrl() async {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.pendingFile)) {
      FileDetailFeature()
    }

    await store.send(.onAppear)
    // No effects — pending file has no URL
  }

  // MARK: - checkFileExistence Tests

  @MainActor
  @Test("checkFileExistence true sets isDownloaded")
  func checkFileExistenceTrue() async {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    }

    await store.send(.checkFileExistence(true)) {
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("checkFileExistence false clears isDownloaded")
  func checkFileExistenceFalse() async {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloaded = true

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.checkFileExistence(false)) {
      $0.isDownloaded = false
    }
  }

  // MARK: - Download Tests

  @MainActor
  @Test("downloadButtonTapped starts download with progress updates and completes")
  func downloadWithProgressAndCompletion() async {
    let markDownloadedCalled = LockIsolated(false)

    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 30))
          continuation.yield(.progress(percent: 60))
          continuation.yield(.completed(localURL: URL(fileURLWithPath: "/tmp/test.mp4")))
          continuation.finish()
        }
      }
      $0.coreDataClient.markFileDownloaded = { _ in markDownloadedCalled.setValue(true) }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.3 }
    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.6 }
    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.downloadProgress = 1.0
      $0.isDownloaded = true
    }

    #expect(markDownloadedCalled.value == true)
  }

  @MainActor
  @Test("downloadButtonTapped does nothing when file has no URL")
  func downloadWithNoUrl() async {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.pendingFile)) {
      FileDetailFeature()
    }

    await store.send(.downloadButtonTapped)
    // No state changes expected
  }

  @MainActor
  @Test("Download failure shows alert with retry button")
  func downloadFails() async {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 20))
          continuation.yield(.failed("Connection lost"))
          continuation.finish()
        }
      }
      $0.logger.log = { _, _, _, _, _, _ in }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadProgressUpdated) { $0.downloadProgress = 0.2 }
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
        TextState("Failed to download \"Test Video.mp4\": Connection lost")
      }
    }
  }

  @MainActor
  @Test("Alert retry triggers download")
  func alertRetryTriggersDownload() async {
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
      $0.coreDataClient.markFileDownloaded = { _ in }
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

  // MARK: - Cancel Download Tests

  @MainActor
  @Test("cancelDownloadButtonTapped resets downloading state and cancels")
  func cancelDownloadResetsState() async {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloading = true
    state.downloadProgress = 0.5

    let cancelCalled = LockIsolated(false)

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    } withDependencies: {
      $0.downloadClient.cancelDownload = { _ in cancelCalled.setValue(true) }
    }

    await store.send(.cancelDownloadButtonTapped) {
      $0.isDownloading = false
      $0.downloadProgress = 0
    }

    #expect(cancelCalled.value == true)
  }

  @MainActor
  @Test("cancelDownloadButtonTapped with no URL still cancels effect")
  func cancelDownloadWithNoUrl() async {
    var state = FileDetailFeature.State(file: TestData.pendingFile)
    state.isDownloading = true
    state.downloadProgress = 0.3

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.cancelDownloadButtonTapped) {
      $0.isDownloading = false
      $0.downloadProgress = 0
    }
  }

  // MARK: - downloadProgressUpdated Tests

  @MainActor
  @Test("downloadProgressUpdated updates progress state")
  func downloadProgressUpdated() async {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloading = true

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.downloadProgressUpdated(0.65)) {
      $0.downloadProgress = 0.65
    }
  }

  // MARK: - Play Tests

  @MainActor
  @Test("playButtonTapped sends delegate playFile action")
  func playButtonTappedSendsDelegate() async {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    }

    await store.send(.playButtonTapped)
    await store.receive(\.delegate.playFile)
  }

  // MARK: - Delete Tests

  @MainActor
  @Test("deleteButtonTapped shows confirmation alert")
  func deleteButtonTappedShowsAlert() async {
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
  @Test("confirmDelete deletes file and sends delegate fileDeleted")
  func confirmDeleteDeletesFile() async {
    let coreDataDeleteCalled = LockIsolated(false)
    let fileDeleteCalled = LockIsolated(false)
    let thumbnailDeleteCalled = LockIsolated(false)

    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.isDownloaded = true

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in coreDataDeleteCalled.setValue(true) }
      $0.fileClient.fileExists = { _ in true }
      $0.fileClient.deleteFile = { _ in fileDeleteCalled.setValue(true) }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in thumbnailDeleteCalled.setValue(true) }
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.alert = nil
    }

    await store.receive(\.delegate.fileDeleted)

    #expect(coreDataDeleteCalled.value == true)
    #expect(fileDeleteCalled.value == true)
    #expect(thumbnailDeleteCalled.value == true)
  }

  @MainActor
  @Test("confirmDelete skips local file removal when file does not exist on disk")
  func confirmDeleteSkipsLocalFileWhenNotExists() async {
    let fileDeleteCalled = LockIsolated(false)
    let thumbnailDeleteCalled = LockIsolated(false)

    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.fileClient.deleteFile = { _ in fileDeleteCalled.setValue(true) }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in thumbnailDeleteCalled.setValue(true) }
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.alert = nil
    }

    await store.receive(\.delegate.fileDeleted)

    #expect(fileDeleteCalled.value == false)
    #expect(thumbnailDeleteCalled.value == true)
  }

  @MainActor
  @Test("Alert dismiss clears alert without side effects")
  func alertDismissClearsAlert() async {
    var state = FileDetailFeature.State(file: TestData.sampleFile)
    state.alert = AlertState {
      TextState("Delete File?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmDelete) {
        TextState("Delete")
      }
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("Cancel")
      }
    } message: {
      TextState("Are you sure?")
    }

    let store = TestStore(initialState: state) {
      FileDetailFeature()
    }

    await store.send(.alert(.presented(.dismiss))) {
      $0.alert = nil
    }
  }

  // MARK: - Share Tests

  @MainActor
  @Test("shareButtonTapped sends delegate shareFile with local URL")
  func shareButtonTappedSendsDelegate() async {
    let localURL = URL(fileURLWithPath: "/var/mobile/Documents/test.mp4")

    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.sampleFile)) {
      FileDetailFeature()
    } withDependencies: {
      $0.fileClient.filePath = { _ in localURL }
    }

    await store.send(.shareButtonTapped)
    await store.receive(\.delegate.shareFile)
  }

  @MainActor
  @Test("shareButtonTapped does nothing when file has no URL")
  func shareButtonTappedWithNoUrl() async {
    let store = TestStore(initialState: FileDetailFeature.State(file: TestData.pendingFile)) {
      FileDetailFeature()
    }

    await store.send(.shareButtonTapped)
    // No effects — pending file has no URL
  }
}
