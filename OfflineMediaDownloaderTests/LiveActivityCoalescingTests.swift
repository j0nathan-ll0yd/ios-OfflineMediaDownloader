import Foundation
@testable import LiveActivityClient
import Testing

// Tests for LA-2/LA-3: single-flight coalescing of Activity.update() calls per fileId.
//
// These tests use LiveActivityManager.registerMockUpdater() to inject a recording closure
// in place of the real ActivityKit Activity.update() call. This avoids any ActivityKit
// runtime dependency while still exercising the full coalescing state machine.
//
// Invariants verified:
//   1. Sequential updates converge currentStates to the latest requested value.
//   2. The external updater receives at least one call; the last received state
//      matches the final currentStates value (convergence).
//   3. After the applier loop drains, no pending desired state remains.
//   4. Updates for different fileIds are independent and both converge correctly.
//   5. updateProgress / updateMetadata on an unknown fileId are safe no-ops.

@Suite("LiveActivityManager coalescing (LA-2/LA-3)")
struct LiveActivityCoalescingTests {
  // MARK: - Helpers

  private func makeInitialState(title: String = "Test Video") -> DownloadActivityAttributes.ContentState {
    DownloadActivityAttributes.ContentState(
      status: .queued,
      progressPercent: 0,
      errorMessage: nil,
      title: title,
      authorName: nil
    )
  }

  // MARK: - Sequential update convergence

  @Test("Sequential updateProgress calls converge currentStates to the latest value")
  func sequentialProgressUpdatesConverge() async {
    let manager = LiveActivityManager()
    let fileId = "file-seq-progress"

    // S72 exemption: test files are exempt per S72 rule; captured inside @Sendable closure.
    nonisolated(unsafe) var appliedStates: [DownloadActivityAttributes.ContentState] = []
    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      appliedStates.append(state)
    }

    await manager.updateProgress(fileId: fileId, percent: 25, status: .downloading)
    await manager.updateProgress(fileId: fileId, percent: 50, status: .downloading)
    await manager.updateProgress(fileId: fileId, percent: 75, status: .downloading)

    let finalState = await manager.currentState(forFileId: fileId)
    #expect(finalState?.progressPercent == 75)
    #expect(finalState?.status == .downloading)
    #expect(!appliedStates.isEmpty, "Updater must be called at least once")
    #expect(appliedStates.last?.progressPercent == finalState?.progressPercent)
  }

  @Test("Sequential updateMetadata calls converge currentStates to the latest title")
  func sequentialMetadataUpdatesConverge() async {
    let manager = LiveActivityManager()
    let fileId = "file-seq-metadata"

    nonisolated(unsafe) var appliedStates: [DownloadActivityAttributes.ContentState] = []
    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      appliedStates.append(state)
    }

    await manager.updateMetadata(fileId: fileId, title: "Title A", authorName: nil)
    await manager.updateMetadata(fileId: fileId, title: "Title B", authorName: "Author B")
    await manager.updateMetadata(fileId: fileId, title: "Title C", authorName: "Author C")

    let finalState = await manager.currentState(forFileId: fileId)
    #expect(finalState?.title == "Title C")
    #expect(finalState?.authorName == "Author C")
    #expect(appliedStates.last?.title == finalState?.title)
  }

  @Test("Mixed updateProgress and updateMetadata calls converge to the latest combined state")
  func mixedUpdatesConverge() async {
    let manager = LiveActivityManager()
    let fileId = "file-mixed"

    nonisolated(unsafe) var appliedStates: [DownloadActivityAttributes.ContentState] = []
    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      appliedStates.append(state)
    }

    await manager.updateProgress(fileId: fileId, percent: 10, status: .downloading)
    await manager.updateMetadata(fileId: fileId, title: "Real Title", authorName: "Author X")
    await manager.updateProgress(fileId: fileId, percent: 90, status: .downloading)

    let finalState = await manager.currentState(forFileId: fileId)
    #expect(finalState?.progressPercent == 90)
    #expect(finalState?.title == "Real Title")
    #expect(finalState?.authorName == "Author X")
  }

  // MARK: - Coalescing: concurrent updates converge to latest

  @Test("Concurrent updates for same fileId: final state is one of the requested values")
  func concurrentUpdatesCoalesce() async {
    let manager = LiveActivityManager()
    let fileId = "file-concurrent"

    // Use an actor to collect applied states safely from concurrent tasks.
    actor StateRecorder {
      var states: [DownloadActivityAttributes.ContentState] = []
      func record(_ s: DownloadActivityAttributes.ContentState) {
        states.append(s)
      }
    }
    let recorder = StateRecorder()

    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      await recorder.record(state)
    }

    await withTaskGroup(of: Void.self) { group in
      for percent in [20, 40, 60, 80, 100] {
        group.addTask {
          await manager.updateProgress(fileId: fileId, percent: percent, status: .downloading)
        }
      }
    }

    let finalState = await manager.currentState(forFileId: fileId)
    let recorded = await recorder.states

    #expect(finalState != nil)
    #expect(!recorded.isEmpty, "Updater must be called at least once")
    // Last delivered state must match what currentStates holds (convergence).
    #expect(recorded.last?.progressPercent == finalState?.progressPercent)
  }

  // MARK: - Independent fileIds do not interfere

  @Test("Updates for different fileIds are independent and both converge")
  func independentFileIdsDoNotInterfere() async {
    let manager = LiveActivityManager()
    let fileId1 = "file-independent-A"
    let fileId2 = "file-independent-B"

    nonisolated(unsafe) var states1: [DownloadActivityAttributes.ContentState] = []
    nonisolated(unsafe) var states2: [DownloadActivityAttributes.ContentState] = []

    await manager.registerMockUpdater(fileId: fileId1, initialState: makeInitialState(title: "A")) { s in
      states1.append(s)
    }
    await manager.registerMockUpdater(fileId: fileId2, initialState: makeInitialState(title: "B")) { s in
      states2.append(s)
    }

    await manager.updateProgress(fileId: fileId1, percent: 33, status: .downloading)
    await manager.updateProgress(fileId: fileId2, percent: 66, status: .serverDownloading)

    let state1 = await manager.currentState(forFileId: fileId1)
    let state2 = await manager.currentState(forFileId: fileId2)

    #expect(state1?.progressPercent == 33)
    #expect(state2?.progressPercent == 66)
    #expect(states1.last?.progressPercent == 33)
    #expect(states2.last?.progressPercent == 66)
  }

  // MARK: - No pending update after applier drains

  @Test("No pending desired state remains after the applier loop completes")
  func noPendingUpdateAfterApplierDrains() async {
    let manager = LiveActivityManager()
    let fileId = "file-no-pending"

    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { _ in }

    await manager.updateProgress(fileId: fileId, percent: 50, status: .downloading)

    let pending = await manager.hasPendingUpdate(forFileId: fileId)
    #expect(!pending, "No desired state should remain after the applier loop drains")
  }

  // MARK: - Unknown fileId no-ops

  @Test("updateProgress on unknown fileId is a no-op and does not crash")
  func updateProgressOnUnknownFileIdIsNoOp() async {
    let manager = LiveActivityManager()
    await manager.updateProgress(fileId: "nonexistent", percent: 50, status: .downloading)
    let state = await manager.currentState(forFileId: "nonexistent")
    #expect(state == nil)
  }

  @Test("updateMetadata on unknown fileId is a no-op and does not crash")
  func updateMetadataOnUnknownFileIdIsNoOp() async {
    let manager = LiveActivityManager()
    await manager.updateMetadata(fileId: "nonexistent", title: "Title", authorName: nil)
    let state = await manager.currentState(forFileId: "nonexistent")
    #expect(state == nil)
  }
}
