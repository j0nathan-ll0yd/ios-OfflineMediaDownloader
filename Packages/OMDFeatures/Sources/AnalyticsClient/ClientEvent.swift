import Foundation

public enum ClientEvent: Encodable, Sendable {
  case pushDelivered(timestamp: Date, correlationId: String, notificationType: String?)
  case pushReceived(timestamp: Date, correlationId: String, notificationType: String?)
  case pushOpened(timestamp: Date, correlationId: String, notificationType: String?)
  case downloadCompletedLocally(timestamp: Date, fileId: String, fileSizeBytes: Int, durationMs: Int)
  case playbackStarted(timestamp: Date, fileId: String, durationSec: Double?)
  case playbackCompleted(timestamp: Date, fileId: String, playbackDurationSec: Double)
  case fileSyncMismatch(timestamp: Date, localCount: Int, serverCount: Int, missingFileIds: [String]?)
  case certificatePinningFailed(timestamp: Date, host: String, errorMessage: String)
  case tokenRefreshSucceeded(timestamp: Date, sessionId: String?)
  case tokenRefreshFailed(timestamp: Date, errorType: String, errorMessage: String)
  case sessionExpired(timestamp: Date, sessionId: String?)
  case backgroundTaskCompleted(timestamp: Date, taskName: String, durationMs: Int)
  case backgroundTaskExpired(timestamp: Date, taskName: String)
  case appLaunched(timestamp: Date, appVersion: String, buildNumber: String, osVersion: String, deviceModel: String)
  case networkError(timestamp: Date, endpoint: String, statusCode: Int?, errorMessage: String)

  private enum CodingKeys: String, CodingKey {
    case eventType, timestamp, correlationId, notificationType
    case fileId, fileSizeBytes, durationMs, durationSec, playbackDurationSec
    case localCount, serverCount, missingFileIds
    case host, errorMessage, errorType
    case sessionId, taskName
    case appVersion, buildNumber, osVersion, deviceModel
    case endpoint, statusCode
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .pushDelivered(timestamp, correlationId, notificationType):
      try container.encode("push_delivered", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(correlationId, forKey: .correlationId)
      try container.encodeIfPresent(notificationType, forKey: .notificationType)

    case let .pushReceived(timestamp, correlationId, notificationType):
      try container.encode("push_received", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(correlationId, forKey: .correlationId)
      try container.encodeIfPresent(notificationType, forKey: .notificationType)

    case let .pushOpened(timestamp, correlationId, notificationType):
      try container.encode("push_opened", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(correlationId, forKey: .correlationId)
      try container.encodeIfPresent(notificationType, forKey: .notificationType)

    case let .downloadCompletedLocally(timestamp, fileId, fileSizeBytes, durationMs):
      try container.encode("download_completed_locally", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(fileId, forKey: .fileId)
      try container.encode(fileSizeBytes, forKey: .fileSizeBytes)
      try container.encode(durationMs, forKey: .durationMs)

    case let .playbackStarted(timestamp, fileId, durationSec):
      try container.encode("playback_started", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(fileId, forKey: .fileId)
      try container.encodeIfPresent(durationSec, forKey: .durationSec)

    case let .playbackCompleted(timestamp, fileId, playbackDurationSec):
      try container.encode("playback_completed", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(fileId, forKey: .fileId)
      try container.encode(playbackDurationSec, forKey: .playbackDurationSec)

    case let .fileSyncMismatch(timestamp, localCount, serverCount, missingFileIds):
      try container.encode("file_sync_mismatch", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(localCount, forKey: .localCount)
      try container.encode(serverCount, forKey: .serverCount)
      try container.encodeIfPresent(missingFileIds, forKey: .missingFileIds)

    case let .certificatePinningFailed(timestamp, host, errorMessage):
      try container.encode("certificate_pinning_failed", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(host, forKey: .host)
      try container.encode(errorMessage, forKey: .errorMessage)

    case let .tokenRefreshSucceeded(timestamp, sessionId):
      try container.encode("token_refresh_succeeded", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encodeIfPresent(sessionId, forKey: .sessionId)

    case let .tokenRefreshFailed(timestamp, errorType, errorMessage):
      try container.encode("token_refresh_failed", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(errorType, forKey: .errorType)
      try container.encode(errorMessage, forKey: .errorMessage)

    case let .sessionExpired(timestamp, sessionId):
      try container.encode("session_expired", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encodeIfPresent(sessionId, forKey: .sessionId)

    case let .backgroundTaskCompleted(timestamp, taskName, durationMs):
      try container.encode("background_task_completed", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(taskName, forKey: .taskName)
      try container.encode(durationMs, forKey: .durationMs)

    case let .backgroundTaskExpired(timestamp, taskName):
      try container.encode("background_task_expired", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(taskName, forKey: .taskName)

    case let .appLaunched(timestamp, appVersion, buildNumber, osVersion, deviceModel):
      try container.encode("app_launched", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(appVersion, forKey: .appVersion)
      try container.encode(buildNumber, forKey: .buildNumber)
      try container.encode(osVersion, forKey: .osVersion)
      try container.encode(deviceModel, forKey: .deviceModel)

    case let .networkError(timestamp, endpoint, statusCode, errorMessage):
      try container.encode("network_error", forKey: .eventType)
      try container.encode(Self.format(timestamp), forKey: .timestamp)
      try container.encode(endpoint, forKey: .endpoint)
      try container.encodeIfPresent(statusCode, forKey: .statusCode)
      try container.encode(errorMessage, forKey: .errorMessage)
    }
  }

  // SAFETY: ISO8601DateFormatter is configured once at init and never mutated — safe for concurrent reads
  private nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static func format(_ date: Date) -> String {
    iso8601.string(from: date)
  }
}

public struct ClientEventBatch: Encodable, Sendable {
  public let events: [ClientEvent]

  public init(events: [ClientEvent]) {
    self.events = events
  }
}
