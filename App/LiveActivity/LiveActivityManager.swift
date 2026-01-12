import ActivityKit
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: "LiveActivity")

actor LiveActivityManager {
  static let shared = LiveActivityManager()
  private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]

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

    let attributes = DownloadActivityAttributes(
      fileId: fileId,
      title: "Queued...",
      authorName: nil
    )

    let initialState = DownloadActivityAttributes.ContentState(
      status: .queued,
      progressPercent: 0,
      errorMessage: nil
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: initialState, staleDate: nil)
      )
      activeActivities[fileId] = activity
      logger.info("Live Activity (pending) started for fileId: \(fileId), activityId: \(activity.id)")
    } catch {
      logger.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  /// Start or update a Live Activity with full file metadata (called from push notification)
  /// If activity already exists (started when queued), this is a no-op since attributes can't be updated
  func startActivity(for file: File) async {
    // If activity already exists from queueing, skip - we can't update static attributes
    if activeActivities[file.fileId] != nil {
      logger.debug("Live Activity already exists for fileId: \(file.fileId), skipping metadata update")
      return
    }

    // Try to start a new activity (will fail if app is in background)
    let authInfo = ActivityAuthorizationInfo()
    logger.info("Starting Live Activity for fileId: \(file.fileId), activitiesEnabled: \(authInfo.areActivitiesEnabled)")

    guard authInfo.areActivitiesEnabled else {
      logger.warning("Live Activities are not enabled")
      return
    }

    let attributes = DownloadActivityAttributes(
      fileId: file.fileId,
      title: file.title ?? "Video",
      authorName: file.authorName
    )

    let initialState = DownloadActivityAttributes.ContentState(
      status: .queued,
      progressPercent: 0,
      errorMessage: nil
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: initialState, staleDate: nil)
      )
      activeActivities[file.fileId] = activity
      logger.info("Live Activity started for fileId: \(file.fileId), activityId: \(activity.id)")
    } catch {
      logger.error("Failed to start Live Activity: \(error.localizedDescription)")
    }
  }

  func updateProgress(fileId: String, percent: Int, status: DownloadActivityStatus) async {
    guard let activity = activeActivities[fileId] else {
      logger.debug("No active Live Activity for fileId: \(fileId)")
      return
    }
    let newState = DownloadActivityAttributes.ContentState(
      status: status,
      progressPercent: percent,
      errorMessage: nil
    )
    await activity.update(ActivityContent(state: newState, staleDate: nil))
    logger.debug("Live Activity updated for fileId: \(fileId), progress: \(percent)%")
  }

  func endActivity(fileId: String, status: DownloadActivityStatus, errorMessage: String? = nil) async {
    guard let activity = activeActivities[fileId] else {
      logger.debug("No active Live Activity to end for fileId: \(fileId)")
      return
    }
    let finalState = DownloadActivityAttributes.ContentState(
      status: status,
      progressPercent: status == .downloaded ? 100 : 0,
      errorMessage: errorMessage
    )
    await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .default)
    activeActivities[fileId] = nil
    logger.info("Live Activity ended for fileId: \(fileId), status: \(status.rawValue)")
  }
}
