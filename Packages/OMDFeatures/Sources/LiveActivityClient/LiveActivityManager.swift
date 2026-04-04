import ActivityKit
import Foundation
import os.log
import SharedModels

// SAFETY: ActivityContent contains only Codable+Hashable state and an optional Date.
// It is safe to send across isolation boundaries when the State type is Sendable.
extension ActivityContent: @retroactive @unchecked Sendable where State: Sendable {}

private let liveActivityLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: "LiveActivity")

public actor LiveActivityManager {
  public static let shared = LiveActivityManager()
  private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]
  private var currentStates: [String: DownloadActivityAttributes.ContentState] = [:]

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
      liveActivityLog.info("Live Activity (pending) started for fileId: \(fileId), activityId: \(activity.id)")
    } catch {
      liveActivityLog.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  public func updateMetadata(fileId: String, title: String, authorName: String?) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId] else {
      liveActivityLog.debug("No active Live Activity to update metadata for fileId: \(fileId)")
      return
    }

    state.title = title
    state.authorName = authorName
    currentStates[fileId] = state

    nonisolated(unsafe) let unsafeActivity = activity
    nonisolated(unsafe) let content = ActivityContent(state: state, staleDate: nil)
    await unsafeActivity.update(content)
    liveActivityLog.info("Live Activity metadata updated for fileId: \(fileId), title: \(title)")
  }

  public func startActivity(for file: File) async {
    if activeActivities[file.fileId] != nil {
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
      liveActivityLog.info("Live Activity started for fileId: \(file.fileId), activityId: \(activity.id)")
    } catch {
      liveActivityLog.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  public func updateProgress(fileId: String, percent: Int, status: DownloadActivityStatus) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId] else {
      liveActivityLog.debug("No active Live Activity for fileId: \(fileId)")
      return
    }

    state.status = status
    state.progressPercent = percent
    currentStates[fileId] = state

    nonisolated(unsafe) let unsafeActivity = activity
    nonisolated(unsafe) let content = ActivityContent(state: state, staleDate: nil)
    await unsafeActivity.update(content)
    liveActivityLog.debug("Live Activity updated for fileId: \(fileId), progress: \(percent)%, status: \(status.rawValue)")
  }

  public func endActivity(fileId: String, status: DownloadActivityStatus, errorMessage: String? = nil) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId] else {
      liveActivityLog.debug("No active Live Activity to end for fileId: \(fileId)")
      return
    }

    state.status = status
    state.progressPercent = status == .downloaded ? 100 : 0
    state.errorMessage = errorMessage

    nonisolated(unsafe) let unsafeActivity = activity
    nonisolated(unsafe) let endState = state
    await unsafeActivity.end(ActivityContent(state: endState, staleDate: nil), dismissalPolicy: .default)
    activeActivities[fileId] = nil
    currentStates[fileId] = nil
    liveActivityLog.info("Live Activity ended for fileId: \(fileId), status: \(status.rawValue)")
  }
}
