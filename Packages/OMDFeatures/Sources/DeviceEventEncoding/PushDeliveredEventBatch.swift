import Foundation

/// Foundation-only encoder for a one-event `push_delivered` batch on `POST /device/event`.
///
/// The Notification Service Extension uses this instead of `AnalyticsClient.ClientEventBatch`,
/// which pulls in APITypes, OpenAPIRuntime, swift-dependencies and UIKit. The extension runs
/// under a tight memory limit on every push, so it links only this target.
///
/// `ClientEventEncodingTests` decodes this output as the generated
/// `Models_period_ClientEventBatchRequest` and compares it with `ClientEventBatch`, so the two
/// encoders cannot drift from the contract or from each other.
public enum PushDeliveredEventBatch {
  /// The contract's `notificationType` enum. A value outside it is omitted, as `ClientEvent` does.
  public static let notificationTypes: Set<String> = [
    "MetadataNotification",
    "DownloadStartedNotification",
    "DownloadProgressNotification",
    "DownloadReadyNotification",
    "FailureNotification",
  ]

  public static func jsonData(correlationId: String, notificationType: String?, timestamp: Date) throws -> Data {
    let event = Event(
      timestamp: timestamp.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      correlationId: correlationId,
      notificationType: notificationType.flatMap { notificationTypes.contains($0) ? $0 : nil }
    )
    return try JSONEncoder().encode(Batch(events: [event]))
  }

  private struct Batch: Encodable {
    let events: [Event]
  }

  private struct Event: Encodable {
    let eventType = "push_delivered"
    let timestamp: String
    let correlationId: String
    let notificationType: String?
  }
}
