import APITypes
import Foundation
import Testing

/// Contract tests that verify the generated Codable types from swift-openapi-generator
/// correctly decode the canonical notification payload fixtures shared with the backend.
///
/// These fixtures live in OfflineMediaDownloaderTests/Fixtures/NotificationPayloads/
/// and are copied from mantle-OfflineMediaDownloader/test/fixtures/notification-payloads/
/// as part of the push notification schema sync (Phase 4b).
@MainActor
struct PushNotificationContractTests {
  // MARK: - Type aliases

  private typealias MetadataPayload = Components.Schemas.Notifications_period_MetadataPayload
  private typealias DownloadReadyPayload = Components.Schemas.Notifications_period_DownloadReadyPayload
  private typealias DownloadStartedPayload = Components.Schemas.Notifications_period_DownloadStartedPayload
  private typealias DownloadProgressPayload = Components.Schemas.Notifications_period_DownloadProgressPayload
  private typealias FailurePayload = Components.Schemas.Notifications_period_FailurePayload

  // MARK: - Fixture loading

  /// Wrapper that mirrors the top-level structure of each fixture JSON:
  /// `{ "notificationType": "...", "file": { ... } }`
  private struct NotificationFixture: Decodable {
    let notificationType: String
    let file: [String: AnyCodable]
  }

  /// Minimal Codable Any wrapper for decoding heterogeneous JSON dictionaries.
  private enum AnyCodable: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(String.self) { self = .string(value); return }
      if let value = try? container.decode(Int.self) { self = .int(value); return }
      if let value = try? container.decode(Double.self) { self = .double(value); return }
      if let value = try? container.decode(Bool.self) { self = .bool(value); return }
      self = .null
    }
  }

  /// Loads a fixture JSON file from the Fixtures/NotificationPayloads/ directory
  /// adjacent to this test source file.
  private func loadFixture(named name: String, sourceFile: String = #filePath) throws -> Data {
    let testDir = URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
    let fixtureURL = testDir
      .appendingPathComponent("Fixtures")
      .appendingPathComponent("NotificationPayloads")
      .appendingPathComponent(name)
    return try Data(contentsOf: fixtureURL)
  }

  /// Extracts the raw `file` dictionary from a fixture and re-encodes it as JSON Data
  /// suitable for decoding into a generated Codable payload type.
  private func fileData(from fixtureData: Data) throws -> Data {
    let json = try JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
    let fileDict = try #require(json?["file"] as? [String: Any])
    return try JSONSerialization.data(withJSONObject: fileDict)
  }

  // MARK: - Tests

  @Test("MetadataNotification fixture decodes into MetadataPayload")
  func metadataFixtureDecodes() throws {
    let raw = try loadFixture(named: "metadata.json")
    let data = try fileData(from: raw)
    let payload = try JSONDecoder().decode(MetadataPayload.self, from: data)

    #expect(payload.fileId == "dQw4w9WgXcQ")
    #expect(payload.key == "dQw4w9WgXcQ.mp4")
    #expect(payload.title == "Rick Astley - Never Gonna Give You Up")
    #expect(payload.authorName == "Rick Astley")
    #expect(payload.authorUser == "rick_astley")
    #expect(payload.contentType == "video/mp4")
    #expect(payload.status == .pending)
    #expect(payload.thumbnailUrl == "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
  }

  @Test("DownloadReadyNotification fixture decodes into DownloadReadyPayload")
  func downloadReadyFixtureDecodes() throws {
    let raw = try loadFixture(named: "download-ready.json")
    let data = try fileData(from: raw)
    let payload = try JSONDecoder().decode(DownloadReadyPayload.self, from: data)

    #expect(payload.fileId == "dQw4w9WgXcQ")
    #expect(payload.key == "dQw4w9WgXcQ.mp4")
    #expect(payload.size == 15_728_640)
    #expect(payload.url == "https://d1example.cloudfront.net/videos/dQw4w9WgXcQ.mp4")
  }

  @Test("DownloadStartedNotification fixture decodes into DownloadStartedPayload")
  func downloadStartedFixtureDecodes() throws {
    let raw = try loadFixture(named: "download-started.json")
    let data = try fileData(from: raw)
    let payload = try JSONDecoder().decode(DownloadStartedPayload.self, from: data)

    #expect(payload.fileId == "dQw4w9WgXcQ")
    #expect(payload.title == "Rick Astley - Never Gonna Give You Up")
    #expect(payload.thumbnailUrl == "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
  }

  @Test("DownloadProgressNotification fixture decodes into DownloadProgressPayload")
  func downloadProgressFixtureDecodes() throws {
    let raw = try loadFixture(named: "download-progress.json")
    let data = try fileData(from: raw)
    let payload = try JSONDecoder().decode(DownloadProgressPayload.self, from: data)

    #expect(payload.fileId == "dQw4w9WgXcQ")
    #expect(payload.progressPercent == 50)
  }

  @Test("FailureNotification fixture decodes into FailurePayload")
  func failureFixtureDecodes() throws {
    let raw = try loadFixture(named: "failure.json")
    let data = try fileData(from: raw)
    let payload = try JSONDecoder().decode(FailurePayload.self, from: data)

    #expect(payload.fileId == "dQw4w9WgXcQ")
    #expect(payload.errorCategory == "permanent")
    #expect(payload.errorMessage == "Video is unavailable in your region")
    #expect(payload.retryExhausted == true)
    #expect(payload.title == "Rick Astley - Never Gonna Give You Up")
  }

  @Test("NotificationType string decodes to correct enum case")
  func notificationTypeEnumDecodes() {
    typealias NotificationType = Components.Schemas.Notifications_period_NotificationType

    #expect(NotificationType(rawValue: "MetadataNotification") == .MetadataNotification)
    #expect(NotificationType(rawValue: "DownloadReadyNotification") == .DownloadReadyNotification)
    #expect(NotificationType(rawValue: "DownloadStartedNotification") == .DownloadStartedNotification)
    #expect(NotificationType(rawValue: "DownloadProgressNotification") == .DownloadProgressNotification)
    #expect(NotificationType(rawValue: "FailureNotification") == .FailureNotification)
    #expect(NotificationType(rawValue: "UnknownType") == nil)
  }
}
