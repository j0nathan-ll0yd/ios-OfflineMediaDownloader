import APITypes
import Foundation

/// The generated `oneOf` item type of `POST /device/event`'s `events` array.
public typealias DeviceEventPayload = Components.Schemas.Models_period_ClientEventBatchRequest.eventsPayloadPayload

public enum ClientEvent: Sendable {
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

  /// The event as the generated `/device/event` contract type.
  ///
  /// A `notificationType` outside the contract enum is omitted: the server rejects
  /// the whole batch for an unknown value, and the field is optional.
  public var payload: DeviceEventPayload {
    switch self {
    case let .pushDelivered(timestamp, correlationId, notificationType):
      .case1(.init(
        eventType: .push_delivered,
        timestamp: timestamp,
        correlationId: correlationId,
        notificationType: notificationType.flatMap { .init(rawValue: $0) }
      ))

    case let .pushReceived(timestamp, correlationId, notificationType):
      .case2(.init(
        eventType: .push_received,
        timestamp: timestamp,
        correlationId: correlationId,
        notificationType: notificationType.flatMap { .init(rawValue: $0) }
      ))

    case let .pushOpened(timestamp, correlationId, notificationType):
      .case3(.init(
        eventType: .push_opened,
        timestamp: timestamp,
        correlationId: correlationId,
        notificationType: notificationType.flatMap { .init(rawValue: $0) }
      ))

    case let .downloadCompletedLocally(timestamp, fileId, fileSizeBytes, durationMs):
      .case4(.init(
        eventType: .download_completed_locally,
        timestamp: timestamp,
        fileId: fileId,
        fileSizeBytes: fileSizeBytes,
        durationMs: durationMs
      ))

    case let .playbackStarted(timestamp, fileId, durationSec):
      .case5(.init(eventType: .playback_started, timestamp: timestamp, fileId: fileId, durationSec: durationSec))

    case let .playbackCompleted(timestamp, fileId, playbackDurationSec):
      .case6(.init(
        eventType: .playback_completed,
        timestamp: timestamp,
        fileId: fileId,
        playbackDurationSec: playbackDurationSec
      ))

    case let .fileSyncMismatch(timestamp, localCount, serverCount, missingFileIds):
      .case7(.init(
        eventType: .file_sync_mismatch,
        timestamp: timestamp,
        localCount: localCount,
        serverCount: serverCount,
        missingFileIds: missingFileIds
      ))

    case let .tokenRefreshSucceeded(timestamp, sessionId):
      .case8(.init(eventType: .token_refresh_succeeded, timestamp: timestamp, sessionId: sessionId))

    case let .tokenRefreshFailed(timestamp, errorType, errorMessage):
      .case9(.init(eventType: .token_refresh_failed, timestamp: timestamp, errorType: errorType, errorMessage: errorMessage))

    case let .sessionExpired(timestamp, sessionId):
      .case10(.init(eventType: .session_expired, timestamp: timestamp, sessionId: sessionId))

    case let .appLaunched(timestamp, appVersion, buildNumber, osVersion, deviceModel):
      .case11(.init(
        eventType: .app_launched,
        timestamp: timestamp,
        appVersion: appVersion,
        buildNumber: buildNumber,
        osVersion: osVersion,
        deviceModel: deviceModel
      ))

    case let .certificatePinningFailed(timestamp, host, errorMessage):
      .case12(.init(eventType: .certificate_pinning_failed, timestamp: timestamp, host: host, errorMessage: errorMessage))

    case let .backgroundTaskCompleted(timestamp, taskName, durationMs):
      .case13(.init(eventType: .background_task_completed, timestamp: timestamp, taskName: taskName, durationMs: durationMs))

    case let .backgroundTaskExpired(timestamp, taskName):
      .case14(.init(eventType: .background_task_expired, timestamp: timestamp, taskName: taskName))

    case let .networkError(timestamp, endpoint, statusCode, errorMessage):
      .case15(.init(
        eventType: .network_error,
        timestamp: timestamp,
        endpoint: endpoint,
        statusCode: statusCode,
        errorMessage: errorMessage
      ))
    }
  }
}

public struct ClientEventBatch: Sendable {
  public let events: [ClientEvent]

  public init(events: [ClientEvent]) {
    self.events = events
  }

  /// The batch as the generated `POST /device/event` request body.
  public var requestBody: Components.Schemas.Models_period_ClientEventBatchRequest {
    .init(events: events.map(\.payload))
  }

  /// The JSON wire form of `requestBody`.
  ///
  /// This is the only sanctioned encoder: the generated types encode `Date` through
  /// the encoder's date strategy, and the contract requires RFC 3339 strings.
  public func jsonData() throws -> Data {
    try Self.encoder.encode(requestBody)
  }

  // SAFETY: JSONEncoder and ISO8601DateFormatter are configured once at init and never mutated — safe for concurrent reads
  private nonisolated(unsafe) static let encoder: JSONEncoder = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(formatter.string(from: date))
    }
    return encoder
  }()
}
