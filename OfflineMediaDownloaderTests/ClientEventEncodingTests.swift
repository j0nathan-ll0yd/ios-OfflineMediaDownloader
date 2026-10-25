import AnalyticsClient
import APITypes
import Foundation
import Testing

// Wire-format tests for the POST /device/event body. ClientEventBatch encodes through
// the generated Components.Schemas.Models_period_ClientEventBatchRequest type; these
// tests pin the JSON it produces to the shape the hand-built encoder sent before.

/// 2025-10-25T13:46:40.250Z — a fractional second proves the timestamp keeps millisecond precision.
private let fixedTimestamp = Date(timeIntervalSince1970: 1_761_400_000.25)
private let fixedTimestampString = "2025-10-25T13:46:40.250Z"
private let correlationId = "6f1c2a9e-3b4d-4e5f-8a7b-9c0d1e2f3a4b"

private func jsonEvents(_ events: [ClientEvent]) throws -> [[String: Any]] {
  let data = try ClientEventBatch(events: events).jsonData()
  let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  #expect(object.keys.sorted() == ["events"])
  return try #require(object["events"] as? [[String: Any]])
}

@Suite("ClientEventBatch JSON wire format")
struct ClientEventEncodingTests {
  @Test("A push_delivered event encodes every field, including the notificationType enum value")
  func pushDeliveredEncodesNotificationType() throws {
    let events = try jsonEvents([
      .pushDelivered(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: "DownloadReadyNotification"),
    ])

    let event = try #require(events.first)
    #expect(events.count == 1)
    #expect(event.keys.sorted() == ["correlationId", "eventType", "notificationType", "timestamp"])
    #expect(event["eventType"] as? String == "push_delivered")
    #expect(event["timestamp"] as? String == fixedTimestampString)
    #expect(event["correlationId"] as? String == correlationId)
    #expect(event["notificationType"] as? String == "DownloadReadyNotification")
  }

  @Test("A notificationType outside the contract enum is omitted, not sent")
  func unknownNotificationTypeIsOmitted() throws {
    let events = try jsonEvents([
      .pushOpened(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: "NotARealNotification"),
    ])

    let event = try #require(events.first)
    #expect(event.keys.sorted() == ["correlationId", "eventType", "timestamp"])
    #expect(event["eventType"] as? String == "push_opened")
  }

  @Test("Nil optional fields are omitted and numbers keep their JSON types")
  func nilOptionalsAreOmitted() throws {
    let events = try jsonEvents([
      .playbackStarted(timestamp: fixedTimestamp, fileId: "file-1", durationSec: nil),
      .networkError(timestamp: fixedTimestamp, endpoint: "/files", statusCode: 503, errorMessage: "unavailable"),
    ])

    #expect(events.count == 2)
    #expect(events[0].keys.sorted() == ["eventType", "fileId", "timestamp"])
    #expect(events[1].keys.sorted() == ["endpoint", "errorMessage", "eventType", "statusCode", "timestamp"])
    #expect(events[1]["statusCode"] as? Int == 503)
  }

  @Test("The encoded batch decodes as the generated contract type")
  func encodedBatchDecodesAsContractType() throws {
    let batch = ClientEventBatch(events: [
      .pushReceived(timestamp: fixedTimestamp, correlationId: correlationId, notificationType: "MetadataNotification"),
      .appLaunched(
        timestamp: fixedTimestamp,
        appVersion: "1.0",
        buildNumber: "1",
        osVersion: "26.0",
        deviceModel: "iPhone18,1"
      ),
    ])

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
}
