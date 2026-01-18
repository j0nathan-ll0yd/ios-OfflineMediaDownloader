import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("ActiveDownloadsFeature Tests")
struct ActiveDownloadsFeatureTests {

  // MARK: - Download Started Tests

  @MainActor
  @Test("Download started adds new download to list")
  func downloadStartedAddsDownload() async throws {
    let store = TestStore(initialState: ActiveDownloadsFeature.State()) {
      ActiveDownloadsFeature()
    }

    await store.send(.downloadStarted(fileId: "file1", title: "Test Video.mp4", isBackground: true)) {
      $0.activeDownloads = [
        .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .downloading, isBackgroundInitiated: true)
      ]
    }
  }

  @MainActor
  @Test("Download started does not add duplicate")
  func downloadStartedNoDuplicate() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 50, status: .downloading, isBackgroundInitiated: true)
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    }

    await store.send(.downloadStarted(fileId: "file1", title: "Test Video.mp4", isBackground: false))
    // No state change expected - duplicate should be ignored
  }

  // MARK: - Progress Update Tests

  @MainActor
  @Test("Download progress update modifies progress value")
  func downloadProgressUpdated() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 0, status: .downloading, isBackgroundInitiated: true)
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    }

    await store.send(.downloadProgressUpdated(fileId: "file1", percent: 45)) {
      $0.activeDownloads[id: "file1"]?.progress = 45
    }
  }

  @MainActor
  @Test("Download progress update for non-existent download does nothing")
  func downloadProgressNonExistent() async throws {
    let store = TestStore(initialState: ActiveDownloadsFeature.State()) {
      ActiveDownloadsFeature()
    }

    await store.send(.downloadProgressUpdated(fileId: "file1", percent: 45))
    // No state change expected
  }

  // MARK: - Download Completed Tests

  @MainActor
  @Test("Download completed updates status")
  func downloadCompleted() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 99, status: .downloading, isBackgroundInitiated: true)
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
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
  func downloadFailed() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test Video.mp4", progress: 50, status: .downloading, isBackgroundInitiated: true)
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
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
  func clearCompleted() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Completed.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
      .init(fileId: "file2", title: "Downloading.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
      .init(fileId: "file3", title: "Failed.mp4", progress: 30, status: .failed("Error"), isBackgroundInitiated: true),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
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
  func clearAll() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test1.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
      .init(fileId: "file2", title: "Test2.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    }

    await store.send(.clearAll) {
      $0.activeDownloads = []
    }
  }

  // MARK: - Remove Download Tests

  @MainActor
  @Test("Remove download removes specific download")
  func removeDownload() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test1.mp4", progress: 100, status: .completed, isBackgroundInitiated: true),
      .init(fileId: "file2", title: "Test2.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false),
    ]

    let store = TestStore(initialState: state) {
      ActiveDownloadsFeature()
    }

    await store.send(.removeDownload(fileId: "file1")) {
      $0.activeDownloads = [
        .init(fileId: "file2", title: "Test2.mp4", progress: 50, status: .downloading, isBackgroundInitiated: false)
      ]
    }
  }

  // MARK: - Computed Property Tests

  @MainActor
  @Test("hasActiveDownloads returns true when downloading")
  func hasActiveDownloadsTrue() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 50, status: .downloading, isBackgroundInitiated: true)
    ]

    #expect(state.hasActiveDownloads == true)
  }

  @MainActor
  @Test("hasActiveDownloads returns false when only completed")
  func hasActiveDownloadsFalseWhenCompleted() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 100, status: .completed, isBackgroundInitiated: true)
    ]

    #expect(state.hasActiveDownloads == false)
  }

  @MainActor
  @Test("hasVisibleDownloads returns true when has any downloads")
  func hasVisibleDownloadsTrue() async throws {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = [
      .init(fileId: "file1", title: "Test.mp4", progress: 100, status: .completed, isBackgroundInitiated: true)
    ]

    #expect(state.hasVisibleDownloads == true)
  }

  @MainActor
  @Test("hasVisibleDownloads returns false when empty")
  func hasVisibleDownloadsFalse() async throws {
    let state = ActiveDownloadsFeature.State()
    #expect(state.hasVisibleDownloads == false)
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has empty downloads")
  func initialStateEmpty() async throws {
    let state = ActiveDownloadsFeature.State()
    #expect(state.activeDownloads.isEmpty)
    #expect(state.hasActiveDownloads == false)
    #expect(state.hasVisibleDownloads == false)
  }
}
