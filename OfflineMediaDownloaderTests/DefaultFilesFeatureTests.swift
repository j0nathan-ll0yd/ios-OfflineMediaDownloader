import ConcurrencyExtras
import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("DefaultFilesFeature Tests")
struct DefaultFilesFeatureTests {

  // MARK: - Loading State Tests

  @MainActor
  @Test("onAppear sets loading state when file is nil")
  func onAppearSetsLoading() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    }

    await store.send(.onAppear) {
      $0.isLoadingFile = true
    }
  }

  @MainActor
  @Test("onAppear does nothing when file already exists")
  func onAppearWithExistingFile() async throws {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.onAppear)
    // No state changes expected - file already present
  }

  // MARK: - Parent Provided File Tests

  @MainActor
  @Test("parentProvidedFile sets file and stops loading")
  func parentProvidedFile() async throws {
    var state = DefaultFilesFeature.State()
    state.isLoadingFile = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.parentProvidedFile(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
      $0.isDownloaded = false
    }
  }

  @MainActor
  @Test("parentProvidedFile marks downloaded when file exists locally")
  func parentProvidedFileAlreadyDownloaded() async throws {
    var state = DefaultFilesFeature.State()
    state.isLoadingFile = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.parentProvidedFile(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("parentProvidedFile handles nil file")
  func parentProvidedNilFile() async throws {
    var state = DefaultFilesFeature.State()
    state.isLoadingFile = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.parentProvidedFile(nil)) {
      $0.isLoadingFile = false
      $0.file = nil
    }
  }

  // MARK: - File Loaded Tests

  @MainActor
  @Test("fileLoaded sets file and checks existence")
  func fileLoaded() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.fileLoaded(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
      $0.isDownloaded = false
    }
  }

  @MainActor
  @Test("fileLoaded with already downloaded file marks as downloaded")
  func fileLoadedAlreadyDownloaded() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.fileLoaded(TestData.sampleFile)) {
      $0.isLoadingFile = false
      $0.file = TestData.sampleFile
      $0.isDownloaded = true
    }
  }

  // MARK: - File Fetch Failed Tests

  @MainActor
  @Test("fileFetchFailed shows error alert")
  func fileFetchFailed() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    }

    await store.send(.fileFetchFailed("Network error")) {
      $0.isLoadingFile = false
      $0.alert = AlertState {
        TextState("Failed to Load")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Network error")
      }
    }
  }

  // MARK: - Download Tests

  @MainActor
  @Test("downloadButtonTapped starts download")
  func downloadButtonTapped() async throws {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in false }
      $0.downloadClient.downloadFile = { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 50))
          continuation.yield(.completed(localURL: URL(fileURLWithPath: "/tmp/test.mp4")))
          continuation.finish()
        }
      }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
      $0.downloadProgress = 0
    }

    await store.receive(\.downloadProgress) {
      $0.downloadProgress = 0.5
    }

    await store.receive(\.downloadCompleted) {
      $0.isDownloading = false
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("downloadButtonTapped does nothing without file")
  func downloadButtonTappedNoFile() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    }

    await store.send(.downloadButtonTapped)
    // No state changes or effects expected
  }

  @MainActor
  @Test("downloadButtonTapped does nothing if file has no URL")
  func downloadButtonTappedNoUrl() async throws {
    var state = DefaultFilesFeature.State()
    state.file = TestData.pendingFile  // Has nil URL

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.downloadButtonTapped)
    // No state changes or effects expected
  }

  @MainActor
  @Test("downloadButtonTapped marks downloaded if file already exists")
  func downloadButtonTappedAlreadyExists() async throws {
    var state = DefaultFilesFeature.State()
    state.file = TestData.sampleFile

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloaded = true
    }
  }

  // MARK: - Download Progress Tests

  @MainActor
  @Test("downloadProgress updates progress value")
  func downloadProgress() async throws {
    var state = DefaultFilesFeature.State()
    state.isDownloading = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.downloadProgress(75)) {
      $0.downloadProgress = 0.75
    }
  }

  // MARK: - Download Completed Tests

  @MainActor
  @Test("downloadCompleted sets downloaded state")
  func downloadCompleted() async throws {
    var state = DefaultFilesFeature.State()
    state.isDownloading = true
    state.downloadProgress = 0.9

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.downloadCompleted(URL(fileURLWithPath: "/tmp/test.mp4"))) {
      $0.isDownloading = false
      $0.isDownloaded = true
    }
  }

  // MARK: - Download Failed Tests

  @MainActor
  @Test("downloadFailed shows alert and resets state")
  func downloadFailed() async throws {
    var state = DefaultFilesFeature.State()
    state.isDownloading = true
    state.downloadProgress = 0.5

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.downloadFailed("Connection lost")) {
      $0.isDownloading = false
      $0.alert = AlertState {
        TextState("Download Failed")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Connection lost")
      }
    }
  }

  // MARK: - Play Tests

  @MainActor
  @Test("playButtonTapped sets preparing state and triggers setPlaying")
  func playButtonTapped() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.coreDataClient.incrementPlayCount = { }
    }

    await store.send(.playButtonTapped) {
      $0.isPreparingToPlay = true
    }

    await store.receive(\.setPlaying) {
      $0.isPlaying = true
    }
  }

  @MainActor
  @Test("setPlaying false clears preparing state")
  func setPlayingFalse() async throws {
    var state = DefaultFilesFeature.State()
    state.isPlaying = true
    state.isPreparingToPlay = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.setPlaying(false)) {
      $0.isPlaying = false
      $0.isPreparingToPlay = false
    }
  }

  @MainActor
  @Test("setPlaying true increments play count")
  func setPlayingTrueIncrementsPlayCount() async throws {
    let incrementCalled = LockIsolated(false)

    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    } withDependencies: {
      $0.coreDataClient.incrementPlayCount = { incrementCalled.setValue(true) }
    }

    await store.send(.setPlaying(true)) {
      $0.isPlaying = true
    }

    // Wait for the effect to complete
    #expect(incrementCalled.value == true)
  }

  // MARK: - Register Button Tests

  @MainActor
  @Test("registerButtonTapped is handled by parent")
  func registerButtonTapped() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    }

    await store.send(.registerButtonTapped)
    // No state changes - handled by parent
  }

  // MARK: - Benefits Toggle Tests

  @MainActor
  @Test("toggleBenefits shows benefits")
  func toggleBenefitsOn() async throws {
    let store = TestStore(initialState: DefaultFilesFeature.State()) {
      DefaultFilesFeature()
    }

    await store.send(.toggleBenefits) {
      $0.showBenefits = true
    }
  }

  @MainActor
  @Test("toggleBenefits hides benefits")
  func toggleBenefitsOff() async throws {
    var state = DefaultFilesFeature.State()
    state.showBenefits = true

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.toggleBenefits) {
      $0.showBenefits = false
    }
  }

  // MARK: - Alert Tests

  @MainActor
  @Test("alert dismiss clears alert")
  func alertDismiss() async throws {
    var state = DefaultFilesFeature.State()
    state.alert = AlertState {
      TextState("Test Alert")
    } actions: {
      ButtonState(action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      DefaultFilesFeature()
    }

    await store.send(.alert(.presented(.dismiss))) {
      $0.alert = nil
    }
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has correct defaults")
  func initialState() async throws {
    let state = DefaultFilesFeature.State()

    #expect(state.isLoadingFile == true)
    #expect(state.file == nil)
    #expect(state.isDownloading == false)
    #expect(state.downloadProgress == 0)
    #expect(state.isDownloaded == false)
    #expect(state.showBenefits == false)
    #expect(state.isPlaying == false)
    #expect(state.isPreparingToPlay == false)
    #expect(state.alert == nil)
  }
}
