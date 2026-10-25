@testable import AnalyticsClient
import APITypes
import Foundation
import Testing

// Wire-format tests for the POST /device/event body. ClientEventBatch encodes through
// the generated Components.Schemas.Models_period_ClientEventBatchRequest type; these
// tests pin the JSON it produces to the shape the hand-built encoder sent before.

/// 2025-10-25T13:46:40.250Z — a fractional second proves the timestamp keeps millisecond precision.
private let fixedTimestamp = Date(timeIntervalSince1970: 1_761_400_000.25)
private let correlationId = "6f1c2a9e-3b4d-4e5f-8a7b-9c0d1e2f3a4b"

/// One event and the exact JSON object the pre-migration encoder produced for it.
/// Every field carries a distinct sentinel, so a swapped argument fails the comparison.
struct WireCase: CustomTestStringConvertible {
  let event: ClientEvent
  let expectedJSON: String

  var testDescription: String {
    String(expectedJSON.split(separator: ",").first ?? "")
  }
}

private let wireCases: [WireCase] = [
  WireCase(
    event: .pushDelivered(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: "DownloadReadyNotification"),
    expectedJSON: #"{"eventType":"push_delivered","timestamp":"2025-10-25T13:46:40.250Z","correlationId":"6f1c2a9e-3b4d-4e5f-8a7b-9c0d1e2f3a4b","notificationType":"DownloadReadyNotification"}"#
  ),
  WireCase(
    event: .pushReceived(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: "MetadataNotification"),
    expectedJSON: #"{"eventType":"push_received","timestamp":"2025-10-25T13:46:40.250Z","correlationId":"6f1c2a9e-3b4d-4e5f-8a7b-9c0d1e2f3a4b","notificationType":"MetadataNotification"}"#
  ),
  WireCase(
    event: .pushOpened(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: nil),
    expectedJSON: #"{"eventType":"push_opened","timestamp":"2025-10-25T13:46:40.250Z","correlationId":"6f1c2a9e-3b4d-4e5f-8a7b-9c0d1e2f3a4b"}"#
  ),
  WireCase(
    event: .downloadCompletedLocally(timestamp: fixedTimestamp, fileId: "file-dl", fileSizeBytes: 1_048_576, durationMs: 4321),
    expectedJSON: #"{"eventType":"download_completed_locally","timestamp":"2025-10-25T13:46:40.250Z","fileId":"file-dl","fileSizeBytes":1048576,"durationMs":4321}"#
  ),
  WireCase(
    event: .playbackStarted(timestamp: fixedTimestamp, fileId: "file-ps", durationSec: 12.5),
    expectedJSON: #"{"eventType":"playback_started","timestamp":"2025-10-25T13:46:40.250Z","fileId":"file-ps","durationSec":12.5}"#
  ),
  WireCase(
    event: .playbackStarted(timestamp: fixedTimestamp, fileId: "file-ps-nil", durationSec: nil),
    expectedJSON: #"{"eventType":"playback_started","timestamp":"2025-10-25T13:46:40.250Z","fileId":"file-ps-nil"}"#
  ),
  WireCase(
    event: .playbackCompleted(timestamp: fixedTimestamp, fileId: "file-pc", playbackDurationSec: 98.25),
    expectedJSON: #"{"eventType":"playback_completed","timestamp":"2025-10-25T13:46:40.250Z","fileId":"file-pc","playbackDurationSec":98.25}"#
  ),
  WireCase(
    event: .fileSyncMismatch(timestamp: fixedTimestamp, localCount: 7, serverCount: 9, missingFileIds: ["m-1", "m-2"]),
    expectedJSON: #"{"eventType":"file_sync_mismatch","timestamp":"2025-10-25T13:46:40.250Z","localCount":7,"serverCount":9,"missingFileIds":["m-1","m-2"]}"#
  ),
  WireCase(
    event: .certificatePinningFailed(timestamp: fixedTimestamp, host: "api.example.test", errorMessage: "pin mismatch"),
    expectedJSON: #"{"eventType":"certificate_pinning_failed","timestamp":"2025-10-25T13:46:40.250Z","host":"api.example.test","errorMessage":"pin mismatch"}"#
  ),
  WireCase(
    event: .tokenRefreshSucceeded(timestamp: fixedTimestamp, sessionId: "session-ok"),
    expectedJSON: #"{"eventType":"token_refresh_succeeded","timestamp":"2025-10-25T13:46:40.250Z","sessionId":"session-ok"}"#
  ),
  WireCase(
    event: .tokenRefreshFailed(timestamp: fixedTimestamp, errorType: "expired", errorMessage: "refresh token expired"),
    expectedJSON: #"{"eventType":"token_refresh_failed","timestamp":"2025-10-25T13:46:40.250Z","errorType":"expired","errorMessage":"refresh token expired"}"#
  ),
  WireCase(
    event: .sessionExpired(timestamp: fixedTimestamp, sessionId: nil),
    expectedJSON: #"{"eventType":"session_expired","timestamp":"2025-10-25T13:46:40.250Z"}"#
  ),
  WireCase(
    event: .backgroundTaskCompleted(timestamp: fixedTimestamp, taskName: "refresh-files", durationMs: 812),
    expectedJSON: #"{"eventType":"background_task_completed","timestamp":"2025-10-25T13:46:40.250Z","taskName":"refresh-files","durationMs":812}"#
  ),
  WireCase(
    event: .backgroundTaskExpired(timestamp: fixedTimestamp, taskName: "expired-task"),
    expectedJSON: #"{"eventType":"background_task_expired","timestamp":"2025-10-25T13:46:40.250Z","taskName":"expired-task"}"#
  ),
  WireCase(
    event: .appLaunched(timestamp: fixedTimestamp, appVersion: "1.2.3", buildNumber: "456", osVersion: "26.0.1", deviceModel: "iPhone18,1"),
    expectedJSON: #"{"eventType":"app_launched","timestamp":"2025-10-25T13:46:40.250Z","appVersion":"1.2.3","buildNumber":"456","osVersion":"26.0.1","deviceModel":"iPhone18,1"}"#
  ),
  WireCase(
    event: .networkError(timestamp: fixedTimestamp, endpoint: "/files", statusCode: 503, errorMessage: "unavailable"),
    expectedJSON: #"{"eventType":"network_error","timestamp":"2025-10-25T13:46:40.250Z","endpoint":"/files","statusCode":503,"errorMessage":"unavailable"}"#
  ),
]

private func jsonObject(_ data: Data) throws -> NSDictionary {
  try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
}

@Suite("ClientEventBatch JSON wire format")
struct ClientEventEncodingTests {
  @Test("Each event type encodes exactly the pre-migration JSON", arguments: wireCases)
  func eventEncodesPreMigrationJSON(_ wireCase: WireCase) throws {
    let batch = try jsonObject(ClientEventBatch(events: [wireCase.event]).jsonData())
    let events = try #require(batch["events"] as? [NSDictionary])
    let expected = try jsonObject(Data(wireCase.expectedJSON.utf8))

    #expect(batch.allKeys.count == 1)
    #expect(events.count == 1)
    #expect(events.first == expected)
  }

  @Test("The wire cases cover all 15 event types in the contract")
  func wireCasesCoverEveryEventType() throws {
    let eventTypes = try Set(wireCases.map { try #require(jsonObject(Data($0.expectedJSON.utf8))["eventType"] as? String) })
    #expect(eventTypes.count == 15)
  }

  @Test("A notificationType outside the contract enum is omitted, not sent")
  func unknownNotificationTypeIsOmitted() throws {
    let batch = try jsonObject(ClientEventBatch(events: [
      .pushOpened(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: "NotARealNotification"),
    ]).jsonData())

    let event = try #require((batch["events"] as? [NSDictionary])?.first)
    #expect(event.allKeys.compactMap { $0 as? String }.sorted() == ["correlationId", "eventType", "timestamp"])
  }

  @Test("The encoded batch decodes as the generated contract type")
  func encodedBatchDecodesAsContractType() throws {
    let batch = ClientEventBatch(events: wireCases.map(\.event))

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let string = try decoder.singleValueContainer().decode(String.self)
      return try Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    // The generated decoder rejects unknown keys, so a round trip proves no field drifts from the contract.
    let decoded = try decoder.decode(
      Components.Schemas.Models_period_ClientEventBatchRequest.self,
      from: batch.jsonData()
    )
    #expect(decoded == batch.requestBody)
  }

  @Test("Contract fields with minimum 0 clamp negatives and reject non-finite numbers")
  func nonNegativeParsersClampAndReject() {
    #expect(nonNegativeInt("42") == 42)
    #expect(nonNegativeInt("-5") == 0)
    #expect(nonNegativeInt("abc") == nil)
    #expect(nonNegativeDouble("12.5") == 12.5)
    #expect(nonNegativeDouble("-0.4") == 0)
    #expect(nonNegativeDouble("nan") == nil)
    #expect(nonNegativeDouble("inf") == nil)
  }
}
