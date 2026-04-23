import APITypes
import ComposableArchitecture
import Foundation

// MARK: - Generated type aliases

private typealias NotificationType = Components.Schemas.Notifications_period_NotificationType
private typealias MetadataPayload = Components.Schemas.Notifications_period_MetadataPayload
private typealias DownloadReadyPayload = Components.Schemas.Notifications_period_DownloadReadyPayload
private typealias DownloadStartedPayload = Components.Schemas.Notifications_period_DownloadStartedPayload
private typealias DownloadProgressPayload = Components.Schemas.Notifications_period_DownloadProgressPayload
private typealias FailurePayload = Components.Schemas.Notifications_period_FailurePayload

// MARK: - PushNotificationType

/// Represents the type of push notification received for file operations
enum PushNotificationType: Equatable {
  /// Full file metadata received (no url, no size) - file is being processed on server
  case metadata(File)
  /// Download URL is ready - can start downloading
  case downloadReady(fileId: String, key: String, url: URL, size: Int64)
  /// Server has started downloading the file to S3
  case downloadStarted(fileId: String, thumbnailUrl: String?, title: String?)
  /// Server-side download progress update (25/50/75%)
  case downloadProgress(fileId: String, progressPercent: Int)
  /// File processing failed
  case failure(fileId: String, title: String?, errorCategory: String, errorMessage: String)
  /// Unknown or malformed notification
  case unknown

  /// Decodes a Codable type from the "file" dictionary inside an APNS userInfo payload.
  private static func decodeFilePayload<T: Decodable>(
    _ type: T.Type,
    from userInfo: [AnyHashable: Any]
  ) -> T? {
    guard let fileDict = userInfo["file"] as? [String: Any],
          let jsonData = try? JSONSerialization.data(withJSONObject: fileDict)
    else { return nil }
    return try? JSONDecoder().decode(type, from: jsonData)
  }

  /// Parse push notification userInfo into a typed notification
  static func parse(from userInfo: [AnyHashable: Any]) -> PushNotificationType {
    @Dependency(\.logger) var logger
    guard let typeString = userInfo["notificationType"] as? String,
          let notificationType = NotificationType(rawValue: typeString)
    else {
      logger.warning(.push, "Unknown or missing notificationType in push notification")
      return .unknown
    }

    switch notificationType {
    case .MetadataNotification:
      guard let payload = decodeFilePayload(MetadataPayload.self, from: userInfo) else {
        logger.warning(.push, "Failed to decode MetadataNotification payload")
        return .unknown
      }
      return .metadata(File(from: payload))

    case .DownloadReadyNotification:
      guard let payload = decodeFilePayload(DownloadReadyPayload.self, from: userInfo),
            let url = URL(string: payload.url)
      else {
        logger.warning(.push, "Failed to decode DownloadReadyNotification payload")
        return .unknown
      }
      return .downloadReady(
        fileId: payload.fileId,
        key: payload.key,
        url: url,
        size: Int64(payload.size)
      )

    case .DownloadStartedNotification:
      guard let payload = decodeFilePayload(DownloadStartedPayload.self, from: userInfo) else {
        logger.warning(.push, "Failed to decode DownloadStartedNotification payload")
        return .unknown
      }
      return .downloadStarted(
        fileId: payload.fileId,
        thumbnailUrl: payload.thumbnailUrl,
        title: payload.title
      )

    case .DownloadProgressNotification:
      guard let payload = decodeFilePayload(DownloadProgressPayload.self, from: userInfo) else {
        logger.warning(.push, "Failed to decode DownloadProgressNotification payload")
        return .unknown
      }
      return .downloadProgress(
        fileId: payload.fileId,
        progressPercent: payload.progressPercent
      )

    case .FailureNotification:
      guard let payload = decodeFilePayload(FailurePayload.self, from: userInfo) else {
        logger.warning(.push, "Failed to decode FailureNotification payload")
        return .unknown
      }
      return .failure(
        fileId: payload.fileId,
        title: payload.title,
        errorCategory: payload.errorCategory,
        errorMessage: payload.errorMessage
      )
    }
  }
}
