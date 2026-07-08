import ActivityKit
import Foundation
import os.log
import SharedModels

// SAFETY: ActivityContent contains only Codable+Hashable state and an optional Date.
// It is safe to send across isolation boundaries when the State type is Sendable.
extension ActivityContent: @retroactive @unchecked Sendable where State: Sendable {}

// SANCTIONED-SINK: LiveActivityManager's local os.log logger; nonisolated-safe let on an actor (Phase-4 LA-4 disposition)
private let liveActivityLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: "LiveActivity")

public actor LiveActivityManager {
  public static let shared = LiveActivityManager()
  private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]
  private var currentStates: [String: DownloadActivityAttributes.ContentState] = [:]

  // LA-2/LA-3: single-flight coalescing for external Activity.update() calls.
  //
  // Problem: two concurrent calls to updateProgress/updateMetadata for the same fileId
  // each capture their own ContentState snapshot before suspending, so the OS can deliver
  // Activity.update() calls out of order — the rendered Live Activity shows stale state.
  //
  // Fix: instead of calling Activity.update() directly, callers write their desired state into
  // desiredStates[fileId] and then either (a) return if an applier is already in flight for
  // that fileId, or (b) run the applier loop themselves. The applier loop repeatedly reads
  // the latest desired state, clears it, applies it via the per-fileId updater, then checks for
  // any newer state that arrived during the await; it exits only when no desired state remains.
  // This guarantees that (1) only one Activity.update() is in flight per fileId at a time,
  // (2) the rendered state always converges to the most-recently-requested value, and
  // (3) endActivity can cancel a pending desired update so a late update cannot re-show an
  //     ended activity.
  private var desiredStates: [String: DownloadActivityAttributes.ContentState] = [:]
  private var applyingFileIds: Set<String> = []

  /// Per-fileId update function: in production captures a real Activity<T> and calls .update();
  /// in tests a mock recorder is injected so the coalescing logic can be verified without
  /// an ActivityKit runtime.
  private var activityUpdaters: [String: @Sendable (DownloadActivityAttributes.ContentState) async -> Void] = [:]

  public func startActivityWithId(fileId: String) async {
    let authInfo = ActivityAuthorizationInfo()
    liveActivityLog.info("Starting Live Activity (pending) for fileId: \(fileId), activitiesEnabled: \(authInfo.areActivitiesEnabled)")

    guard authInfo.areActivitiesEnabled else {
      liveActivityLog.warning("Live Activities are not enabled")
      return
    }

    if activeActivities[fileId] != nil {
      liveActivityLog.debug("Live Activity already exists for fileId: \(fileId)")
      return
    }

    let attributes = DownloadActivityAttributes(fileId: fileId)

    let initialState = DownloadActivityAttributes.ContentState(
      status: .queued,
      progressPercent: 0,
      errorMessage: nil,
      title: "Queued...",
      authorName: nil
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: initialState, staleDate: nil)
      )
      activeActivities[fileId] = activity
      currentStates[fileId] = initialState
      // SAFETY: Activity<T> is not Sendable; capture into nonisolated(unsafe) local so the
      // closure below can be stored in the Sendable-typed dict without crossing isolation.
      nonisolated(unsafe) let unsafeActivity = activity
      activityUpdaters[fileId] = { state in
        // SAFETY: ActivityContent is not Sendable; constructed outside actor isolation for use with nonisolated Activity API
        nonisolated(unsafe) let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
        await unsafeActivity.update(content)
      }
      liveActivityLog.info("Live Activity (pending) started for fileId: \(fileId), activityId: \(activity.id)")
    } catch {
      liveActivityLog.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  public func updateMetadata(fileId: String, title: String, authorName: String?) async {
    guard activityUpdaters[fileId] != nil,
          var state = currentStates[fileId]
    else {
      liveActivityLog.debug("No active Live Activity to update metadata for fileId: \(fileId)")
      return
    }

    state.title = title
    state.authorName = authorName
    currentStates[fileId] = state

    await applyDesiredState(state, forFileId: fileId)
    liveActivityLog.info("Live Activity metadata updated for fileId: \(fileId), title: \(title)")
  }

  public func startActivity(for file: File) async {
    if activityUpdaters[file.fileId] != nil {
      await updateMetadata(fileId: file.fileId, title: file.title ?? "Video", authorName: file.authorName)
      return
    }

    let authInfo = ActivityAuthorizationInfo()
    liveActivityLog.info("Starting Live Activity for fileId: \(file.fileId), activitiesEnabled: \(authInfo.areActivitiesEnabled)")

    guard authInfo.areActivitiesEnabled else {
      liveActivityLog.warning("Live Activities are not enabled")
      return
    }

    let attributes = DownloadActivityAttributes(fileId: file.fileId)

    let initialState = DownloadActivityAttributes.ContentState(
      status: .queued,
      progressPercent: 0,
      errorMessage: nil,
      title: file.title ?? "Video",
      authorName: file.authorName
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: initialState, staleDate: nil)
      )
      activeActivities[file.fileId] = activity
      currentStates[file.fileId] = initialState
      // SAFETY: Activity<T> is not Sendable; capture into nonisolated(unsafe) local so the
      // closure below can be stored in the Sendable-typed dict without crossing isolation.
      nonisolated(unsafe) let unsafeActivity = activity
      activityUpdaters[file.fileId] = { state in
        // SAFETY: ActivityContent is not Sendable; constructed outside actor isolation for use with nonisolated Activity API
        nonisolated(unsafe) let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
        await unsafeActivity.update(content)
      }
      liveActivityLog.info("Live Activity started for fileId: \(file.fileId), activityId: \(activity.id)")
    } catch {
      liveActivityLog.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  public func updateProgress(fileId: String, percent: Int, status: DownloadActivityStatus) async {
    guard activityUpdaters[fileId] != nil,
          var state = currentStates[fileId]
    else {
      liveActivityLog.debug("No active Live Activity for fileId: \(fileId)")
      return
    }

    state.status = status
    state.progressPercent = percent
    currentStates[fileId] = state

    await applyDesiredState(state, forFileId: fileId)
    liveActivityLog.debug("Live Activity updated for fileId: \(fileId), progress: \(percent)%, status: \(status.rawValue)")
  }

  public func endActivity(fileId: String, status: DownloadActivityStatus, errorMessage: String? = nil) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId]
    else {
      liveActivityLog.debug("No active Live Activity to end for fileId: \(fileId)")
      return
    }

    state.status = status
    state.progressPercent = status == .downloaded ? 100 : 0
    state.errorMessage = errorMessage

    // Remove entries before the await so that reentrant calls (updateProgress, updateMetadata,
    // or a second endActivity for the same fileId) that suspend on the actor during .end()
    // find no live entry and bail early rather than operating on a dying activity.
    // Also cancel any pending coalesced update so a late applier cannot re-show an ended activity.
    activeActivities[fileId] = nil
    currentStates[fileId] = nil
    desiredStates[fileId] = nil
    activityUpdaters[fileId] = nil

    // SAFETY: Activity<T> is not Sendable; escaping actor isolation is required to call .end() from async context
    nonisolated(unsafe) let unsafeActivity = activity
    // SAFETY: ActivityContent is not Sendable; constructed outside actor isolation for use with nonisolated Activity .end() API
    nonisolated(unsafe) let endState = state
    await unsafeActivity.end(ActivityContent(state: endState, staleDate: nil), dismissalPolicy: .default)
    liveActivityLog.info("Live Activity ended for fileId: \(fileId), status: \(status.rawValue)")
  }

  // MARK: - Testing support

  #if DEBUG
    /// Returns the current actor-side ContentState for a fileId.
    /// Tests use this to assert that currentStates converged to the expected value
    /// after a sequence of updateProgress/updateMetadata calls completes.
    func currentState(forFileId fileId: String) -> DownloadActivityAttributes.ContentState? {
      currentStates[fileId]
    }

    /// Returns whether a desired-state update is pending or in flight for a fileId.
    /// Tests use this to assert that endActivity cleared the pending update queue.
    func hasPendingUpdate(forFileId fileId: String) -> Bool {
      desiredStates[fileId] != nil || applyingFileIds.contains(fileId)
    }

    /// Registers a mock update function for a fileId, bypassing the real ActivityKit Activity.
    /// Call this in tests to simulate an active activity and capture applied states.
    /// Guards in updateProgress/updateMetadata check activityUpdaters[fileId] != nil, so
    /// registering here is sufficient to make those methods route through the mock updater.
    /// endActivity still requires activeActivities[fileId] for its .end() call; tests that
    /// exercise endActivity should call this then verify desiredStates is cleared directly.
    /// Only for use in unit tests — not part of the public production API.
    func registerMockUpdater(
      fileId: String,
      initialState: DownloadActivityAttributes.ContentState,
      updater: @escaping @Sendable (DownloadActivityAttributes.ContentState) async -> Void
    ) {
      currentStates[fileId] = initialState
      activityUpdaters[fileId] = updater
    }
  #endif

  // MARK: - Private

  /// Single-flight coalescing applier for external Activity.update() calls (LA-2/LA-3 fix).
  ///
  /// Sets `state` as the desired state for `fileId`. If an applier loop is already running
  /// for this fileId, returns immediately — the running loop will pick up the new desired
  /// state after its current await completes. Otherwise, this call becomes the applier and
  /// loops until no pending desired state remains, then clears the in-flight marker.
  ///
  /// Invariants:
  ///   - At most one Activity.update() is in flight per fileId at any time.
  ///   - The rendered state always converges to the most-recently-requested value.
  ///   - endActivity clears desiredStates[fileId] before its await, so a concurrent applier
  ///     loop will drain to nil and exit without issuing an update on an ended activity.
  private func applyDesiredState(_ state: DownloadActivityAttributes.ContentState, forFileId fileId: String) async {
    // Record the latest desired state. If an applier is already running for this fileId,
    // it will pick this up after its current Activity.update() await completes.
    desiredStates[fileId] = state
    guard !applyingFileIds.contains(fileId) else { return }

    // Become the applier for this fileId.
    applyingFileIds.insert(fileId)
    defer { applyingFileIds.remove(fileId) }

    // Drain loop: keep applying until no pending desired state remains.
    while let nextState = desiredStates[fileId] {
      desiredStates[fileId] = nil

      // Guard: endActivity may have cleared activityUpdaters[fileId] before this point.
      guard let updater = activityUpdaters[fileId] else { break }

      await updater(nextState)
      // After the await the actor resumes with exclusive access. Any desiredStates[fileId]
      // written during the await by a concurrent updateProgress/updateMetadata will be picked
      // up in the next loop iteration.
    }
  }
}
