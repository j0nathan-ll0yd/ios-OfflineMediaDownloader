import AnalyticsClient
import ComposableArchitecture
import ConcurrencyExtras
@testable import DownloadTrackingFeature
@testable import FileListFeature
import Foundation
import LiveActivityClient
import LoggerClient
import PasteboardClient
import PersistenceClient
import Testing

// Analytics durations come from MonotonicClock, never from wall-clock Date differences.
// These tests drive each duration site with a controlled clock and assert the tracked value.

@Suite("Analytics durations use the monotonic clock")
struct AnalyticsDurationTests {
  @MainActor
  @Test("Download duration is the monotonic difference in whole milliseconds")
  func downloadDurationUsesMonotonicClock() async {
    let tracked = LockIsolated<[String: String]?>(nil)
    var state = DownloadTrackingFeature.State()
    state.downloadStartTimes["file-1"] = .seconds(10)

    let store = TestStore(initialState: state) {
      DownloadTrackingFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.monotonicClock.now = { .milliseconds(12345) }
      $0.analytics.track = { event, properties in
        if event == .downloadCompletedLocally {
          tracked.setValue(properties)
        }
      }
      $0.liveActivityClient.endActivity = { _, _, _ in }
      $0.coreDataClient.markFileDownloaded = { _ in }
    }
    store.exhaustivity = .off

    await store.send(.downloadCompleted(fileId: "file-1")) {
      $0.downloadStartTimes = [:]
    }
    await store.receive(\.delegate.refreshFileState)

    #expect(tracked.value?["durationMs"] == "2345")
  }

  @MainActor
  @Test("Playback duration is the monotonic difference in seconds")
  func playbackDurationUsesMonotonicClock() async {
    let tracked = LockIsolated<[String: String]?>(nil)
    var state = FileListFeature.State()
    state.playingFile = TestData.sampleFile
    state.playbackStartTime = .seconds(100)

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.monotonicClock.now = { .seconds(103.5) }
      $0.analytics.track = { event, properties in
        if event == .playbackCompleted {
          tracked.setValue(properties)
        }
      }
    }

    await store.send(.dismissPlayer) {
      $0.playingFile = nil
      $0.playbackStartTime = nil
    }

    #expect(tracked.value?["playbackDurationSec"] == "3.5")
    #expect(tracked.value?["fileId"] == TestData.sampleFile.fileId)
  }
}
