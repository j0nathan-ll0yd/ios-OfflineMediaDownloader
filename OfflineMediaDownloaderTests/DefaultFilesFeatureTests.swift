import ComposableArchitecture
import ConcurrencyExtras
import Foundation
@testable import OfflineMediaDownloader
import Testing

@Suite(.serialized)
struct DefaultFilesFeatureTests {
  // MARK: - onAppear Tests

  @MainActor
  @Test("onAppear with no file sets isLoadingFile true")
  func onAppearWithNoFileSetsLoading() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.onAppear)
    // isLoadingFile is already true by default in State init;
    // onAppear sets it to true again (no-op), so no state change expected
  }

  @MainActor
  @Test("onAppear with existing file does nothing")
  func onAppearWithExistingFileDoesNothing() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile
    state.isLoadingFile = false

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.onAppear)
    // No state changes expected when file is already set
  }

  // MARK: - parentProvidedFile Tests

  @MainActor
  @Test("parentProvidedFile sets file and stops loading")
  func parentProvidedFileSetsFileAndStopsLoading() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.parentProvidedFile(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
    }
  }

  @MainActor
  @Test("parentProvidedFile sets isDownloaded true when file exists locally")
  func parentProvidedFileMarksDownloadedWhenExists() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.parentProvidedFile(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("parentProvidedFile with nil file sets isLoadingFile false and file nil")
  func parentProvidedFileWithNilFile() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.parentProvidedFile(nil)) {
      $0.isLoadingFile = false
      $0.file = nil
    }
  }

  // MARK: - fileLoaded Tests

  @MainActor
  @Test("fileLoaded sets file and stops loading")
  func fileLoadedSetsFile() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.fileLoaded(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
    }
  }

  @MainActor
  @Test("fileLoaded marks downloaded when local file exists")
  func fileLoadedMarksDownloaded() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.fileLoaded(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
      $0.isDownloaded = true
    }
  }

  // MARK: - fileFetchFailed Tests

  @MainActor
  @Test("fileFetchFailed stops loading and shows alert")
  func fileFetchFailedShowsAlert() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.fileFetchFailed("Could not load files.")) {
      $0.isLoadingFile = false
      $0.alert = AlertState {
        TextState("Failed to Load")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Could not load files.")
      }
    }
  }

  // MARK: - Download Tests

  @MainActor
  @Test("downloadButtonTapped starts download with progress updates")
  func downloadButtonTappedStartsDownload() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in false }
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
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

    await store.receive(\.downloadProgress) { $0.downloadProgress = 0.5 }
    await store.receive(\.downloadProgress) { $0.downloadProgress = 1.0 }
    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("downloadButtonTapped marks already-downloaded when file exists")
  func downloadButtonTappedWhenFileAlreadyExists() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("downloadButtonTapped does nothing without a file")
  func downloadButtonTappedWithNoFile() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadButtonTapped)
    // No state changes expected
  }

  @MainActor
  @Test("downloadButtonTapped does nothing when file has no URL")
  func downloadButtonTappedWithNoUrl() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.pendingFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadButtonTapped)
    // No state changes expected — pending file has no URL
  }

  @MainActor
  @Test("Download failure resets state and shows alert")
  func downloadFails() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.fileClient.fileExists = { _ in false }
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 25))
          continuation.yield(.failed("Network timeout"))
          continuation.finish()
        }
      }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadProgress) { $0.downloadProgress = 0.25 }
    await store.receive(\.downloadFailed) {
      $0.isDownloading = false
      $0.alert = AlertState {
        TextState("Download Failed")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Network timeout")
      }
    }
  }

  // MARK: - downloadProgress Tests

  @MainActor
  @Test("downloadProgress action updates progress correctly")
  func downloadProgressUpdatesState() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile
    state.isDownloading = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadProgress(75)) {
      $0.downloadProgress = 0.75
    }
  }

  // MARK: - downloadCompleted Tests

  @MainActor
  @Test("downloadCompleted sets isDownloaded and clears isDownloading")
  func downloadCompletedSetsState() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile
    state.isDownloading = true
    state.downloadProgress = 0.9

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadCompleted(URL(fileURLWithPath: "/tmp/test.mp4"))) {
      $0.isDownloading = false
      $0.isDownloaded = true
    }
  }

  // MARK: - Play Tests

  @MainActor
  @Test("playButtonTapped sets isPreparingToPlay and then isPlaying")
  func playButtonTappedSetsPlaying() async {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile
    state.isDownloaded = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.coreDataClient.incrementPlayCount = {}
    }

    await store.send(.playButtonTapped) {
      $0.isPreparingToPlay = true
    }

    await store.receive(\.setPlaying) {
      $0.isPlaying = true
    }
  }

  @MainActor
  @Test("setPlaying false clears isPlaying and isPreparingToPlay")
  func setPlayingFalseClearsState() async {
    var state = DefaultFilesFeature.State()
    state.isPlaying = true
    state.isPreparingToPlay = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.setPlaying(false)) {
      $0.isPlaying = false
      $0.isPreparingToPlay = false
    }
  }

  @MainActor
  @Test("setPlaying true increments play count")
  func setPlayingTrueIncrementsPlayCount() async {
    let incrementCalled = LockIsolated(false)

    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.coreDataClient.incrementPlayCount = { incrementCalled.setValue(true) }
    }

    await store.send(.setPlaying(true)) {
      $0.isPlaying = true
    }

    #expect(incrementCalled.value == true)
  }

  // MARK: - toggleBenefits Tests

  @MainActor
  @Test("toggleBenefits flips showBenefits")
  func toggleBenefitsFlips() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.toggleBenefits) {
      $0.showBenefits = true
    }

    await store.send(.toggleBenefits) {
      $0.showBenefits = false
    }
  }

  // MARK: - registerButtonTapped Tests

  @MainActor
  @Test("registerButtonTapped does nothing (handled by parent)")
  func registerButtonTappedIsNoOp() async {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.registerButtonTapped)
    // No state changes expected — handled by parent
  }

  // MARK: - Alert Tests

  @MainActor
  @Test("Alert dismiss action clears alert")
  func alertDismissClearsAlert() async {
    var state = DefaultFilesFeature.State()
    state.alert = AlertState {
      TextState("Download Failed")
    } actions: {
      ButtonState(action: .dismiss) {
        TextState("OK")
      }
    } message: {
      TextState("Something went wrong.")
    }

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.alert(.presented(.dismiss))) {
      $0.alert = nil
    }
  }
}
