import Foundation

/// Represents the type of push notification received for file operations
enum PushNotificationType: Equatable, Sendable {
  /// Full file metadata received (no url, no size) - file is being processed on server
  case metadata(File)
  /// Download URL is ready - can start downloading
  case downloadReady(fileId: String, key: String, url: URL, size: Int64)
  /// File processing failed
  case failure(fileId: String, title: String?, errorCategory: String, errorMessage: String)
  /// Unknown or malformed notification
  case unknown

  /// Parse push notification userInfo into a typed notification
  static func parse(from userInfo: [AnyHashable: Any]) -> PushNotificationType {
    guard let notificationType = userInfo["notificationType"] as? String,
          let fileData = userInfo["file"] as? [String: Any] else {
      return .unknown
    }

    switch notificationType {
    case "MetadataNotification":
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: fileData)
        let decoder = JSONDecoder()
        // File.init(from:) handles both date formats automatically
        let file = try decoder.decode(File.self, from: jsonData)
        return .metadata(file)
      } catch {
        print("Failed to decode file from MetadataNotification: \(error)")
        return .unknown
      }

    case "DownloadReadyNotification":
      guard let fileId = fileData["fileId"] as? String,
            let key = fileData["key"] as? String,
            let urlString = fileData["url"] as? String,
            let url = URL(string: urlString),
            let size = fileData["size"] as? Int else {
        print("Missing required fields in DownloadReadyNotification")
        return .unknown
      }
      return .downloadReady(fileId: fileId, key: key, url: url, size: Int64(size))

    case "FailureNotification":
      guard let fileId = fileData["fileId"] as? String,
            let errorCategory = fileData["errorCategory"] as? String,
            let errorMessage = fileData["errorMessage"] as? String else {
        print("Missing required fields in FailureNotification")
        return .unknown
      }
      let title = fileData["title"] as? String
      return .failure(fileId: fileId, title: title, errorCategory: errorCategory, errorMessage: errorMessage)

    default:
      print("Unknown notificationType: \(notificationType)")
      return .unknown
    }
  }
}
