@testable import ActiveDownloadsFeature
import ComposableArchitecture
import Foundation
import LoggerClient
import Testing

@Suite(.serialized)
struct ActiveDownloadsFeatureTests {
  // MARK: - Download Started Tests

  @MainActor
  @Test("Download started adds new download to list")
  func downloadStartedAddsDownload() async {
    let store = TestStore(initialState: ActiveDownloadsFeature.State()) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadStarted(fileId: "file1", title: "Test Video.mp4", isBackground: true)) {
      $0.activeDownloads = [
        .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .downloading, isBackgroundInitiated: true),
      ]
    }
  }

  @MainActor
  @Test("Download started transitions existing queued entry to downloading")
  func downloadStartedTransitionsExisting() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 50, status: .serverDownloading, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadStarted(fileId: "file1", title: "Test Video.mp4", isBackground: true)) {
      $0.activeDownloads[id: "file1"]?.status = .downloading
      $0.activeDownloads[id: "file1"]?.progress = 0
      $0.activeDownloads[id: "file1"]?.isBackgroundInitiated = true
    }
  }

  // MARK: - Server Lifecycle Tests

  @MainActor
  @Test("File queued adds download with queued status")
  func fileQueuedAddsDownload() async {
    let store = TestStore(initialState: ActiveDownloadsFeature.State()) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.fileQueued(fileId: "file1", title: "Test Video.mp4")) {
      $0.activeDownloads = [
        .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .queued, isBackgroundInitiated: false),
      ]
    }
  }

  @MainActor
  @Test("File queued does not add duplicate")
  func fileQueuedNoDuplicate() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .queued, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.fileQueued(fileId: "file1", title: "Test Video.mp4"))
  }

  @MainActor
  @Test("Server download started transitions from queued to serverDownloading")
  func serverDownloadStarted() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .queued, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.serverDownloadStarted(fileId: "file1")) {
      $0.activeDownloads[id: "file1"]?.status = .serverDownloading
    }
  }

  @MainActor
  @Test("Server download progress updates percent")
  func serverDownloadProgressUpdated() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .serverDownloading, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.serverDownloadProgressUpdated(fileId: "file1", percent: 65)) {
      $0.activeDownloads[id: "file1"]?.progress = 65
    }
  }

  // MARK: - Progress Update Tests

  @MainActor
  @Test("Download progress update modifies progress value")
  func downloadProgressUpdated() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .downloading, isBackgroundInitiated: true),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadProgressUpdated(fileId: "file1", percent: 45)) {
      $0.activeDownloads[id: "file1"]?.progress = 45
    }
  }

  @MainActor
  @Test("Download progress update for non-existent download does nothing")
  func downloadProgressNonExistent() async {
    let store = TestStore(initialState: ActiveDownloadsFeature.State()) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.downloadProgressUpdated(fileId: "file1", percent: 45))
    // No state change expected
  }

  // MARK: - Download Completed Tests

  @MainActor
  @Test("Download completed updates status")
  func downloadCompleted() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 99, status: .downloading, isBackgroundInitiated: true),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }
    store.exhaustivity = .off

    await store.send(.downloadCompleted(fileId: "file1")) {
      $0.activeDownloads[id: "file1"]?.progress = 100
      $0.activeDownloads[id: "file1"]?.status = .completed
    }
    // Auto-remove effect is triggered but not asserted (exhaustivity is off)
  }

  // MARK: - Download Failed Tests

  @MainActor
  @Test("Download failed updates status")
  func downloadFailed() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 50, status: .downloading, isBackgroundInitiated: true),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }
    store.exhaustivity = .off

    await store.send(.downloadFailed(fileId: "file1", error: "Network error")) {
      $0.activeDownloads[id: "file1"]?.status = .failed("Network error")
    }
    // Auto-remove effect is triggered but not asserted (exhaustivity is off)
  }

  // MARK: - Clear Actions Tests

  @MainActor
  @Test("Clear completed removes only completed downloads")
  func clearCompleted() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Completed.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
      .init(fileId: "file2", title: "Downloading.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
      .init(fileId: "file3", title: "Failed.mp4", progress: 30, status: .failed("Error"), isBackgroundInitiated: true),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.clearCompleted) {
      $0.activeDownloads = [
        .init(fileId: "file2", title: "Downloading.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
        .init(fileId: "file3", title: "Failed.mp4", progress: 30, status: .failed("Error"), isBackgroundInitiated: true),
      ]
    }
  }

  @MainActor
  @Test("Clear all removes all downloads")
  func clearAll() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test1.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
      .init(fileId: "file2", title: "Test2.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.clearAll) {
      $0.activeDownloads = []
    }
  }

  // MARK: - Remove Download Tests

  @MainActor
  @Test("Remove download removes specific download")
  func removeDownload() async {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test1.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
      .init(fileId: "file2", title: "Test2.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
    }

    await store.send(.removeDownload(fileId: "file1")) {
      $0.activeDownloads = [
        .init(fileId: "file2", title: "Test2.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
      ]
    }
  }

  // MARK: - Computed Property Tests

  @MainActor
  @Test("hasActiveDownloads returns true when downloading")
  func hasActiveDownloadsTrue() {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 50, status: .downloading, isBackgroundInitiated: true),
    ]

    #expect(state.hasActiveDownloads == true)
  }

  @MainActor
  @Test("hasActiveDownloads returns true when queued")
  func hasActiveDownloadsTrueWhenQueued() {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 0, status: .queued, isBackgroundInitiated: false),
    ]

    #expect(state.hasActiveDownloads == true)
  }

  @MainActor
  @Test("hasActiveDownloads returns true when server downloading")
  func hasActiveDownloadsTrueWhenServerDownloading() {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 30, status: .serverDownloading, isBackgroundInitiated: false),
    ]

    #expect(state.hasActiveDownloads == true)
  }

  @MainActor
  @Test("hasActiveDownloads returns false when only completed")
  func hasActiveDownloadsFalseWhenCompleted() {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
    ]

    #expect(state.hasActiveDownloads == false)
  }

  @MainActor
  @Test("hasVisibleDownloads returns true when has any downloads")
  func hasVisibleDownloadsTrue() {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
    ]

    #expect(state.hasVisibleDownloads == true)
  }

  @MainActor
  @Test("hasVisibleDownloads returns false when empty")
  func hasVisibleDownloadsFalse() {
    let state = ActiveDownloadsFeature.State()
    #expect(state.hasVisibleDownloads == false)
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has empty downloads")
  func initialStateEmpty() {
    let state = ActiveDownloadsFeature.State()
    #expect(state.activeDownloads.isEmpty)
    #expect(state.hasActiveDownloads == false)
    #expect(state.hasVisibleDownloads == false)
  }
}
