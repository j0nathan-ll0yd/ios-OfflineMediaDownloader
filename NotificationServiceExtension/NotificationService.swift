import Foundation
import os
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private static let logger = Logger(
    subsystem: "lifegames.OfflineMediaDownloader.NotificationServiceExtension",
    category: "NotificationService"
  )

  private static let appGroupId = "group.lifegames.OfflineMediaDownloader"

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

    let userInfo = request.content.userInfo
    guard let notificationId = userInfo["notificationId"] as? String else {
      Self.logger.info("No notificationId in push payload — delivering without confirmation")
      contentHandler(request.content)
      return
    }

    let notificationType = userInfo["notificationType"] as? String
    Self.logger.info("Received alert push: notificationId=\(notificationId)")

    Task {
      await sendPushDeliveredEvent(
        notificationId: notificationId,
        notificationType: notificationType
      )
      if let content = bestAttemptContent {
        contentHandler(content)
      } else {
        contentHandler(request.content)
      }
    }
  }

  override func serviceExtensionTimeWillExpire() {
    Self.logger.warning("NSE time expiring — delivering best attempt content")
    if let contentHandler, let bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }

  // MARK: - Event Posting

  private func sendPushDeliveredEvent(
    notificationId: String,
    notificationType: String?
  ) async {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    guard let apiKey = infoDictionary["MEDIA_DOWNLOADER_API_KEY"] as? String, !apiKey.isEmpty else {
      Self.logger.error("MEDIA_DOWNLOADER_API_KEY not found in bundle")
      return
    }
    guard let basePath = infoDictionary["MEDIA_DOWNLOADER_BASE_PATH"] as? String,
          let baseURL = URL(string: basePath)
    else {
      Self.logger.error("MEDIA_DOWNLOADER_BASE_PATH not found or invalid")
      return
    }

    let sharedDefaults = UserDefaults(suiteName: Self.appGroupId)
    guard let deviceId = sharedDefaults?.string(forKey: "deviceUUID"), !deviceId.isEmpty else {
      Self.logger.error("No deviceUUID in shared App Group defaults")
      return
    }

    let url = baseURL.appendingPathComponent("device/event")
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "ApiKey", value: apiKey)]

    guard let requestURL = components?.url else {
      Self.logger.error("Failed to construct request URL")
      return
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var event: [String: Any] = [
      "eventType": "push_delivered",
      "timestamp": formatter.string(from: Date()),
      "correlationId": notificationId,
    ]
    if let notificationType {
      event["notificationType"] = notificationType
    }

    let body: [String: Any] = ["events": [event]]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
      Self.logger.error("Failed to serialize event JSON")
      return
    }

    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(deviceId, forHTTPHeaderField: "x-device-uuid")
    request.httpBody = jsonData
    request.timeoutInterval = 25

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      Self.logger.info("push_delivered event sent: status=\(statusCode)")
    } catch {
      Self.logger.error("Failed to send push_delivered event: \(error.localizedDescription)")
    }
  }
}
