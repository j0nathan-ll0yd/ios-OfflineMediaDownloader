import APIClient
import Foundation
import SharedModels

/// Centralized test data fixtures for all feature tests
public enum TestData {
  // MARK: - Files

  public static let sampleFile = File(
    fileId: "test-file-123",
    key: "Test Video.mp4",
    publishDate: Date(timeIntervalSince1970: 1_700_000_000),
    size: 1_024_000,
    url: URL(string: "https://example.com/test.mp4")
  )

  public static let pendingFile: File = .init(
    fileId: "pending-file-456",
    key: "Pending Video.mp4",
    publishDate: Date(timeIntervalSince1970: 1_700_000_000),
    size: nil,
    url: nil // No URL = pending
  )

  public static let downloadedFile = File(
    fileId: "downloaded-file-789",
    key: "Downloaded Video.mp4",
    publishDate: Date(timeIntervalSince1970: 1_699_000_000),
    size: 2_048_000,
    url: URL(string: "https://example.com/downloaded.mp4")
  )

  public static let multipleFiles: [File] = [
    sampleFile,
    downloadedFile,
    File(
      fileId: "file-3",
      key: "Another Video.mp4",
      publishDate: Date(timeIntervalSince1970: 1_698_000_000),
      size: 512_000,
      url: URL(string: "https://example.com/another.mp4")
    ),
  ]

  // MARK: - Users

  public static let sampleUser = User(
    email: "test@example.com",
    firstName: "Test",
    identifier: "user-123",
    lastName: "User"
  )

  public static let newUser = User(
    email: "new@example.com",
    firstName: "New",
    identifier: "new-user-456",
    lastName: "Person"
  )

  // MARK: - Devices

  public static let sampleDevice = Device(endpointArn: "arn:aws:sns:us-west-2:123456789:endpoint/test")

  // MARK: - API Responses

  public static let validLoginResponse = LoginResponse(
    body: TokenResponse(token: "test-jwt-token-valid", expiresAt: nil, sessionId: "session-123", userId: "user-123"),
    error: nil,
    requestId: "request-123"
  )

  public static let loginResponseWithError = LoginResponse(
    body: nil,
    error: ErrorDetail(message: "Invalid credentials", code: "AUTH_ERROR"),
    requestId: "request-456"
  )

  public static let loginResponseNilBody = LoginResponse(
    body: nil,
    error: nil,
    requestId: "request-789"
  )

  public static let validFileResponse = FileResponse(
    body: FileList(contents: multipleFiles, keyCount: 3),
    error: nil,
    requestId: "request-files-123"
  )

  public static let emptyFileResponse = FileResponse(
    body: FileList(contents: [], keyCount: 0),
    error: nil,
    requestId: "request-files-empty"
  )

  public static let fileResponseWithError = FileResponse(
    body: nil,
    error: ErrorDetail(message: "Internal server error", code: "SERVER_ERROR"),
    requestId: "request-files-error"
  )

  public static let validRegisterDeviceResponse = RegisterDeviceResponse(
    body: EndpointResponse(endpointArn: "arn:aws:sns:us-west-2:123456789:endpoint/new"),
    error: nil,
    requestId: "request-device-123"
  )

  public static let validAddFileResponse = DownloadFileResponse(
    body: DownloadFileResponseDetail(status: "queued"),
    error: nil,
    requestId: "request-add-123"
  )

  // MARK: - Push Notification Payloads

  public nonisolated(unsafe) static let metadataPushPayload: [AnyHashable: Any] = [
    "aps": ["content-available": 1],
    "type": "metadata",
    "file": [
      "fileId": "push-file-123",
      "key": "Push Video.mp4",
      "publishDate": "2024-01-15",
      "size": 1_500_000,
    ],
  ]

  public nonisolated(unsafe) static let downloadReadyPushPayload: [AnyHashable: Any] = [
    "aps": ["content-available": 1],
    "type": "download-ready",
    "fileId": "push-file-123",
    "key": "push-video.mp4",
    "url": "https://example.com/push-video.mp4",
    "size": 1_500_000,
  ]

  // MARK: - Tokens

  public static let validJwtToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTUxNjIzOTAyMn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

  public static let shortToken = "short-token-for-display"

  // MARK: - Error Helpers

  public struct TestNetworkError: Error, LocalizedError {
    public let message: String
    public var errorDescription: String? {
      message
    }

    /// NSError with NSURLErrorNotConnectedToInternet - properly detected by AppError.from()
    public static let notConnected = NSError(
      domain: NSURLErrorDomain,
      code: NSURLErrorNotConnectedToInternet,
      userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
    )

    /// NSError with NSURLErrorTimedOut - properly detected by AppError.from()
    public static let timeout = NSError(
      domain: NSURLErrorDomain,
      code: NSURLErrorTimedOut,
      userInfo: [NSLocalizedDescriptionKey: "The request timed out."]
    )

    public static let serverError = TestNetworkError(message: "Internal server error")
  }
}
