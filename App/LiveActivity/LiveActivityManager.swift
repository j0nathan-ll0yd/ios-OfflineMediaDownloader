import ActivityKit
import Foundation

actor LiveActivityManager {
  static let shared = LiveActivityManager()
  private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]

  func startActivity(for file: File) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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

    let activity = try Activity.request(
      attributes: attributes,
      content: ActivityContent(state: initialState, staleDate: nil)
    )
    activeActivities[file.fileId] = activity
  }

  func updateProgress(fileId: String, percent: Int, status: DownloadActivityStatus) async {
    guard let activity = activeActivities[fileId] else { return }
    let newState = DownloadActivityAttributes.ContentState(
      status: status,
      progressPercent: percent,
      errorMessage: nil
    )
    await activity.update(ActivityContent(state: newState, staleDate: nil))
  }

  func endActivity(fileId: String, status: DownloadActivityStatus, errorMessage: String? = nil) async {
    guard let activity = activeActivities[fileId] else { return }
    let finalState = DownloadActivityAttributes.ContentState(
      status: status,
      progressPercent: status == .downloaded ? 100 : 0,
      errorMessage: errorMessage
    )
    await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .default)
    activeActivities[fileId] = nil
  }
}
