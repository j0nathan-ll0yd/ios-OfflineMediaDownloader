import Foundation
@testable import OfflineMediaDownloader
import Testing

/// Contract tests that verify push notification fixture payloads from the backend
/// are correctly parsed by `PushNotificationType.parse(from:)`.
///
/// These fixtures live in OfflineMediaDownloaderTests/Fixtures/NotificationPayloads/
/// and are copied from mantle-OfflineMediaDownloader/test/fixtures/notification-payloads/
/// as part of the push notification schema sync (Phase 4b).
///
/// If a backend notification schema changes, these fixtures update, and these tests
/// fail until the iOS parser handles the new shape.
@MainActor
struct PushNotificationContractTests {
  // MARK: - Fixture loading

  /// Loads a fixture JSON file and converts it to the `[AnyHashable: Any]` dictionary
  /// format that mirrors APNS `userInfo`.
  private func loadUserInfo(named name: String, sourceFile: String = #filePath) throws -> [AnyHashable: Any] {
    let testDir = URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
    let fixtureURL = testDir
      .appendingPathComponent("Fixtures")
      .appendingPathComponent("NotificationPayloads")
      .appendingPathComponent(name)
    let data = try Data(contentsOf: fixtureURL)
    let json = try JSONSerialization.jsonObject(with: data)
    return try #require(json as? [AnyHashable: Any])
  }

  // MARK: - Tests

  @Test("MetadataNotification fixture parses to .metadata case")
  func metadataFixtureParses() throws {
    let userInfo = try loadUserInfo(named: "metadata.json")
    let result = PushNotificationType.parse(from: userInfo)

    guard case let .metadata(file) = result else {
      Issue.record("Expected .metadata, got \(result)")
      return
    }
    #expect(file.fileId == "dQw4w9WgXcQ")
    #expect(file.key == "dQw4w9WgXcQ.mp4")
    #expect(file.title == "Rick Astley - Never Gonna Give You Up")
    #expect(file.authorName == "Rick Astley")
  }

  @Test("DownloadReadyNotification fixture parses to .downloadReady case")
  func downloadReadyFixtureParses() throws {
    let userInfo = try loadUserInfo(named: "download-ready.json")
    let result = PushNotificationType.parse(from: userInfo)

    guard case let .downloadReady(fileId, key, url, size) = result else {
      Issue.record("Expected .downloadReady, got \(result)")
      return
    }
    #expect(fileId == "dQw4w9WgXcQ")
    #expect(key == "dQw4w9WgXcQ.mp4")
    #expect(url.absoluteString == "https://d1example.cloudfront.net/videos/dQw4w9WgXcQ.mp4")
    #expect(size == 15_728_640)
  }

  @Test("DownloadStartedNotification fixture parses to .downloadStarted case")
  func downloadStartedFixtureParses() throws {
    let userInfo = try loadUserInfo(named: "download-started.json")
    let result = PushNotificationType.parse(from: userInfo)

    guard case let .downloadStarted(fileId, thumbnailUrl, title) = result else {
      Issue.record("Expected .downloadStarted, got \(result)")
      return
    }
    #expect(fileId == "dQw4w9WgXcQ")
    #expect(title == "Rick Astley - Never Gonna Give You Up")
    #expect(thumbnailUrl == "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
  }

  @Test("DownloadProgressNotification fixture parses to .downloadProgress case")
  func downloadProgressFixtureParses() throws {
    let userInfo = try loadUserInfo(named: "download-progress.json")
    let result = PushNotificationType.parse(from: userInfo)

    guard case let .downloadProgress(fileId, progressPercent) = result else {
      Issue.record("Expected .downloadProgress, got \(result)")
      return
    }
    #expect(fileId == "dQw4w9WgXcQ")
    #expect(progressPercent == 50)
  }

  @Test("FailureNotification fixture parses to .failure case")
  func failureFixtureParses() throws {
    let userInfo = try loadUserInfo(named: "failure.json")
    let result = PushNotificationType.parse(from: userInfo)

    guard case let .failure(fileId, _, errorCategory, errorMessage) = result else {
      Issue.record("Expected .failure, got \(result)")
      return
    }
    #expect(fileId == "dQw4w9WgXcQ")
    #expect(errorCategory == "permanent")
    #expect(errorMessage == "Video is unavailable in your region")
  }

  @Test("Unknown notification type parses to .unknown")
  func unknownTypeParses() {
    let userInfo: [AnyHashable: Any] = [
      "notificationType": "SomeNewType",
      "file": ["fileId": "test"],
    ]
    let result = PushNotificationType.parse(from: userInfo)
    #expect(result == .unknown)
  }
}
