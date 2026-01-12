import ActivityKit
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: "LiveActivity")

actor LiveActivityManager {
  static let shared = LiveActivityManager()
  private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]

  func startActivity(for file: File) async {
    let authInfo = ActivityAuthorizationInfo()
    logger.info("Starting Live Activity for fileId: \(file.fileId), activitiesEnabled: \(authInfo.areActivitiesEnabled)")

    guard authInfo.areActivitiesEnabled else {
      logger.warning("Live Activities are not enabled. User needs to enable in Settings > OfflineMediaDownloader > Live Activities")
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
      logger.info("Live Activity started successfully for fileId: \(file.fileId), activityId: \(activity.id)")
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
