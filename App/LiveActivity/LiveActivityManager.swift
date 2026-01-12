import ActivityKit
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: "LiveActivity")

actor LiveActivityManager {
  static let shared = LiveActivityManager()
  private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]
  // Track current state so we can preserve title/author when updating progress
  private var currentStates: [String: DownloadActivityAttributes.ContentState] = [:]

  /// Start a Live Activity with just a fileId (used when queueing, before metadata is available)
  func startActivityWithId(fileId: String) async {
    let authInfo = ActivityAuthorizationInfo()
    logger.info("Starting Live Activity (pending) for fileId: \(fileId), activitiesEnabled: \(authInfo.areActivitiesEnabled)")

    guard authInfo.areActivitiesEnabled else {
      logger.warning("Live Activities are not enabled")
      return
    }

    // Check if already have an activity for this fileId
    if activeActivities[fileId] != nil {
      logger.debug("Live Activity already exists for fileId: \(fileId)")
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
      logger.info("Live Activity (pending) started for fileId: \(fileId), activityId: \(activity.id)")
    } catch {
      logger.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  /// Update Live Activity with metadata when received from push notification
  func updateMetadata(fileId: String, title: String, authorName: String?) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId] else {
      logger.debug("No active Live Activity to update metadata for fileId: \(fileId)")
      return
    }

    state.title = title
    state.authorName = authorName
    currentStates[fileId] = state

    await activity.update(ActivityContent(state: state, staleDate: nil))
    logger.info("Live Activity metadata updated for fileId: \(fileId), title: \(title)")
  }

  /// Start a Live Activity with full file metadata (called from push notification if no activity exists)
  func startActivity(for file: File) async {
    // If activity already exists, just update the metadata
    if activeActivities[file.fileId] != nil {
      await updateMetadata(fileId: file.fileId, title: file.title ?? "Video", authorName: file.authorName)
      return
    }

    // Try to start a new activity (will fail if app is in background)
    let authInfo = ActivityAuthorizationInfo()
    logger.info("Starting Live Activity for fileId: \(file.fileId), activitiesEnabled: \(authInfo.areActivitiesEnabled)")

    guard authInfo.areActivitiesEnabled else {
      logger.warning("Live Activities are not enabled")
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
      logger.info("Live Activity started for fileId: \(file.fileId), activityId: \(activity.id)")
    } catch {
      logger.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  func updateProgress(fileId: String, percent: Int, status: DownloadActivityStatus) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId] else {
      logger.debug("No active Live Activity for fileId: \(fileId)")
      return
    }

    state.status = status
    state.progressPercent = percent
    currentStates[fileId] = state

    await activity.update(ActivityContent(state: state, staleDate: nil))
    logger.debug("Live Activity updated for fileId: \(fileId), progress: \(percent)%, status: \(status.rawValue)")
  }

  func endActivity(fileId: String, status: DownloadActivityStatus, errorMessage: String? = nil) async {
    guard let activity = activeActivities[fileId],
          var state = currentStates[fileId] else {
      logger.debug("No active Live Activity to end for fileId: \(fileId)")
      return
    }

    state.status = status
    state.progressPercent = status == .downloaded ? 100 : 0
    state.errorMessage = errorMessage

    await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default)
    activeActivities[fileId] = nil
    currentStates[fileId] = nil
    logger.info("Live Activity ended for fileId: \(fileId), status: \(status.rawValue)")
  }
}
