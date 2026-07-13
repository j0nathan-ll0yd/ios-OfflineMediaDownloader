import ConcurrencyExtras
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
//   6. (Race regression) cancelActivityStateForTesting mid-flight causes the applier
//      to issue NO further updates and leaves hasPendingUpdate == false.

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

    let appliedStates = LockIsolated<[DownloadActivityAttributes.ContentState]>([])
    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      appliedStates.withValue { $0.append(state) }
    }

    await manager.updateProgress(fileId: fileId, percent: 25, status: .downloading)
    await manager.updateProgress(fileId: fileId, percent: 50, status: .downloading)
    await manager.updateProgress(fileId: fileId, percent: 75, status: .downloading)

    let finalState = await manager.currentState(forFileId: fileId)
    #expect(finalState?.progressPercent == 75)
    #expect(finalState?.status == .downloading)
    #expect(!appliedStates.value.isEmpty, "Updater must be called at least once")
    #expect(appliedStates.value.last?.progressPercent == finalState?.progressPercent)
  }

  @Test("Sequential updateMetadata calls converge currentStates to the latest title")
  func sequentialMetadataUpdatesConverge() async {
    let manager = LiveActivityManager()
    let fileId = "file-seq-metadata"

    let appliedStates = LockIsolated<[DownloadActivityAttributes.ContentState]>([])
    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      appliedStates.withValue { $0.append(state) }
    }

    await manager.updateMetadata(fileId: fileId, title: "Title A", authorName: nil)
    await manager.updateMetadata(fileId: fileId, title: "Title B", authorName: "Author B")
    await manager.updateMetadata(fileId: fileId, title: "Title C", authorName: "Author C")

    let finalState = await manager.currentState(forFileId: fileId)
    #expect(finalState?.title == "Title C")
    #expect(finalState?.authorName == "Author C")
    #expect(appliedStates.value.last?.title == finalState?.title)
  }

  @Test("Mixed updateProgress and updateMetadata calls converge to the latest combined state")
  func mixedUpdatesConverge() async {
    let manager = LiveActivityManager()
    let fileId = "file-mixed"

    let appliedStates = LockIsolated<[DownloadActivityAttributes.ContentState]>([])
    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { state in
      appliedStates.withValue { $0.append(state) }
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

    let states1 = LockIsolated<[DownloadActivityAttributes.ContentState]>([])
    let states2 = LockIsolated<[DownloadActivityAttributes.ContentState]>([])

    await manager.registerMockUpdater(fileId: fileId1, initialState: makeInitialState(title: "A")) { s in
      states1.withValue { $0.append(s) }
    }
    await manager.registerMockUpdater(fileId: fileId2, initialState: makeInitialState(title: "B")) { s in
      states2.withValue { $0.append(s) }
    }

    await manager.updateProgress(fileId: fileId1, percent: 33, status: .downloading)
    await manager.updateProgress(fileId: fileId2, percent: 66, status: .serverDownloading)

    let state1 = await manager.currentState(forFileId: fileId1)
    let state2 = await manager.currentState(forFileId: fileId2)

    #expect(state1?.progressPercent == 33)
    #expect(state2?.progressPercent == 66)
    #expect(states1.value.last?.progressPercent == 33)
    #expect(states2.value.last?.progressPercent == 66)
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

  // MARK: - Race regression: endActivity cancellation during applier in-flight

  // Pins the invariant from the LA-2/LA-3 audit (INFO-2):
  //
  //   While an applier has an `await updater(...)` in flight, cancelActivityStateForTesting
  //   (which mirrors endActivity's synchronous prologue) clears desiredStates[fileId] and
  //   activityUpdaters[fileId]. When the applier's await returns and the actor resumes,
  //   the next loop iteration hits `guard let updater = activityUpdaters[fileId] else { break }`
  //   and exits — issuing NO further update call and leaving hasPendingUpdate == false.
  //
  // Test shape: deterministic via continuations, no sleeps.
  //   1. Register a mock updater that suspends on a continuation (simulates the in-flight await).
  //   2. Enqueue a second desired state WHILE the updater is suspended (simulates a concurrent caller).
  //   3. Invoke the cancellation seam while the updater is still suspended.
  //   4. Resume the updater continuation.
  //   5. Assert: updater called exactly once; hasPendingUpdate == false.
  //
  // Companion happy-path: without cancellation, a queued desired state still drains
  // (guards that the seam cannot silently break normal convergence).

  @Test("endActivity cancellation mid-flight: applier exits after current await, issues no further update")
  func endActivityCancellationMidFlightStopsApplier() async {
    let manager = LiveActivityManager()
    let fileId = "file-race-cancel"

    // Tracks how many times the updater closure was called.
    let callCount = LockIsolated(0)
    // Continuation that the test holds to control when the first updater call resumes.
    let inFlightContinuation = LockIsolated<CheckedContinuation<Void, Never>?>(nil)

    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { _ in
      callCount.withValue { $0 += 1 }
      // Suspend here until the test resumes us, simulating an in-flight Activity.update() await.
      await withCheckedContinuation { continuation in
        inFlightContinuation.withValue { $0 = continuation }
      }
    }

    // Start the applier by requesting a progress update. The applier suspends inside the mock.
    async let applierTask: Void = manager.updateProgress(fileId: fileId, percent: 50, status: .downloading)

    // Spin until the mock updater has captured its continuation (i.e. the applier is suspended).
    while inFlightContinuation.value == nil {
      await Task.yield()
    }

    // Enqueue a second desired state while the applier is suspended.
    // This would be the "next iteration" candidate — the race candidate.
    async let secondUpdate: Void = manager.updateProgress(fileId: fileId, percent: 99, status: .downloading)

    // Invoke the cancellation seam (mirrors endActivity's synchronous prologue).
    await manager.cancelActivityStateForTesting(fileId: fileId)

    // Resume the suspended updater — the applier's await now returns.
    inFlightContinuation.value?.resume()

    // Let all tasks complete.
    await applierTask
    await secondUpdate

    // The updater must have been called exactly once (the in-flight call we controlled).
    // A second call would mean the applier ignored the cancellation and issued another update.
    #expect(callCount.value == 1, "Updater must be called exactly once; got \(callCount.value)")

    // No pending update must remain — the cancelled applier should have drained cleanly.
    let pending = await manager.hasPendingUpdate(forFileId: fileId)
    #expect(!pending, "hasPendingUpdate must be false after cancellation")
  }

  @Test("Happy path: queued desired state drains normally without cancellation")
  func queuedDesiredStateDrainsWithoutCancellation() async {
    let manager = LiveActivityManager()
    let fileId = "file-race-happy"

    let callCount = LockIsolated(0)
    let inFlightContinuation = LockIsolated<CheckedContinuation<Void, Never>?>(nil)

    await manager.registerMockUpdater(fileId: fileId, initialState: makeInitialState()) { _ in
      callCount.withValue { $0 += 1 }
      await withCheckedContinuation { continuation in
        inFlightContinuation.withValue { $0 = continuation }
      }
    }

    // Start first applier — suspends inside the mock.
    async let firstUpdate: Void = manager.updateProgress(fileId: fileId, percent: 50, status: .downloading)

    while inFlightContinuation.value == nil {
      await Task.yield()
    }

    // Enqueue a second desired state while the first is suspended.
    async let secondUpdate: Void = manager.updateProgress(fileId: fileId, percent: 99, status: .downloading)

    // Resume the first call — the applier picks up the queued state and calls updater again.
    let firstContinuation = inFlightContinuation.value
    inFlightContinuation.withValue { $0 = nil }
    firstContinuation?.resume()

    // Wait for the second updater invocation to reach its suspension.
    while callCount.value < 2 {
      await Task.yield()
    }

    // Resume the second call.
    inFlightContinuation.value?.resume()

    await firstUpdate
    await secondUpdate

    // Both desired states were drained: updater called at least twice and final state converged.
    #expect(callCount.value >= 2, "Updater must drain queued state; got \(callCount.value) calls")
    let finalState = await manager.currentState(forFileId: fileId)
    #expect(finalState?.progressPercent == 99)
    let pending = await manager.hasPendingUpdate(forFileId: fileId)
    #expect(!pending)
  }
}
