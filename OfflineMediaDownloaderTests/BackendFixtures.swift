import Foundation
@testable import OfflineMediaDownloader

/// Backend-sourced test fixtures for integration testing
/// These fixtures are synced from the backend E2E test infrastructure
/// using Scripts/sync-backend-fixtures.sh
enum BackendFixtures {

  // MARK: - Fixture Loading

  private static let fixturesBundle: Bundle = {
    // Look for fixtures in the test bundle
    Bundle(for: BundleLocator.self)
  }()

  private static func loadJSON<T: Decodable>(_ filename: String) -> T? {
    // Try bundle resource first
    if let url = fixturesBundle.url(forResource: filename, withExtension: "json") {
      return loadJSON(from: url)
    }

    // Fall back to Fixtures directory relative to test file
    let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
    let fixturesURL = testDir.appendingPathComponent("Fixtures/\(filename).json")
    return loadJSON(from: fixturesURL)
  }

  private static func loadJSON<T: Decodable>(from url: URL) -> T? {
    guard let data = try? Data(contentsOf: url) else {
      print("Warning: Could not load fixture file: \(url.lastPathComponent)")
      return nil
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      print("Warning: Could not decode fixture file \(url.lastPathComponent): \(error)")
      return nil
    }
  }

  // MARK: - LocalStack Configuration

  struct LocalStackConfig: Decodable {
    let description: String
    let endpoints: Endpoints
    let apiKey: String
    let region: String

    struct Endpoints: Decodable {
      let apiGateway: String
      let s3: String
      let sns: String
    }
  }

  static var localStackConfig: LocalStackConfig? {
    loadJSON("localstack-config")
  }

  // MARK: - Mock SIWA Tokens

  struct MockSIWATokens: Decodable {
    let description: String
    let tokens: [String: TokenData]

    struct TokenData: Decodable {
      let identityToken: String
      let userId: String
      let email: String
      let firstName: String?
      let lastName: String?
    }
  }

  static var mockSIWATokens: MockSIWATokens? {
    loadJSON("mock-siwa-tokens")
  }

  /// Get the mock identity token for a valid existing user
  static var validUserIdentityToken: String? {
    mockSIWATokens?.tokens["validUser"]?.identityToken
  }

  /// Get the mock identity token for a new user registration
  static var newUserIdentityToken: String? {
    mockSIWATokens?.tokens["newUser"]?.identityToken
  }

  // MARK: - API Response Fixtures

  struct APIResponses: Decodable {
    let description: String
    let responses: ResponseData

    struct ResponseData: Decodable {
      let loginSuccess: LoginResponseFixture
      let registerDeviceSuccess: RegisterDeviceFixture
      let fileListSuccess: FileListFixture
      let addFileSuccess: AddFileFixture
    }

    struct LoginResponseFixture: Decodable {
      let body: LoginBody

      struct LoginBody: Decodable {
        let token: String
        let expiresAt: String?
        let sessionId: String?
        let userId: String?
      }
    }

    struct RegisterDeviceFixture: Decodable {
      let body: RegisterDeviceBody

      struct RegisterDeviceBody: Decodable {
        let endpointArn: String
      }
    }

    struct FileListFixture: Decodable {
      let body: FileListBody

      struct FileListBody: Decodable {
        let contents: [FileFixture]
        let keyCount: Int
      }

      struct FileFixture: Decodable {
        let fileId: String
        let key: String
        let publishDate: String?
        let size: Int?
        let url: String?
        let status: String?
        let title: String?
        let authorName: String?
      }
    }

    struct AddFileFixture: Decodable {
      let body: AddFileBody

      struct AddFileBody: Decodable {
        let status: String
      }
    }
  }

  static var apiResponses: APIResponses? {
    loadJSON("api-responses")
  }

  // MARK: - Push Notification Fixtures

  struct PushNotifications: Decodable {
    let description: String
    let notifications: NotificationData

    struct NotificationData: Decodable {
      let fileMetadata: FileMetadataNotification
      let downloadReady: DownloadReadyNotification
    }

    struct FileMetadataNotification: Decodable {
      let aps: APS
      let type: String
      let file: FileData

      struct FileData: Decodable {
        let fileId: String
        let key: String
        let publishDate: String
        let size: Int
      }
    }

    struct DownloadReadyNotification: Decodable {
      let aps: APS
      let type: String
      let fileId: String
      let key: String
      let url: String
      let size: Int
    }

    struct APS: Decodable {
      let contentAvailable: Int

      enum CodingKeys: String, CodingKey {
        case contentAvailable = "content-available"
      }
    }
  }

  static var pushNotifications: PushNotifications? {
    loadJSON("push-notifications")
  }

  // MARK: - Conversion to Domain Models

  /// Convert backend file fixture to domain File model
  static func convertToFile(_ fixture: APIResponses.FileListFixture.FileFixture) -> File {
    var file = File(
      fileId: fixture.fileId,
      key: fixture.key,
      publishDate: parseDate(fixture.publishDate),
      size: fixture.size,
      url: fixture.url.flatMap { URL(string: $0) }
    )
    file.title = fixture.title
    file.authorName = fixture.authorName
    if let statusString = fixture.status {
      file.status = FileStatus(rawValue: statusString.lowercased())
    }
    return file
  }

  /// Get files from backend fixture as domain models
  static var files: [File] {
    guard let fileList = apiResponses?.responses.fileListSuccess.body.contents else {
      return []
    }
    return fileList.map { convertToFile($0) }
  }

  private static func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }

    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    // Try YYYYMMDD format
    formatter.dateFormat = "yyyyMMdd"
    if let date = formatter.date(from: dateString) {
      return date
    }

    // Try ISO format
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString)
  }
}

// MARK: - Bundle Locator

private class BundleLocator {}
