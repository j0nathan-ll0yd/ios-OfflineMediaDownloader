import Foundation
@testable import OfflineMediaDownloader

/// Centralized test data fixtures for all feature tests
enum TestData {

  // MARK: - Files

  static let sampleFile = File(
    fileId: "test-file-123",
    key: "Test Video.mp4",
    publishDate: Date(timeIntervalSince1970: 1700000000),
    size: 1024000,
    url: URL(string: "https://example.com/test.mp4")
  )

  static let pendingFile: File = {
    var file = File(
      fileId: "pending-file-456",
      key: "Pending Video.mp4",
      publishDate: Date(timeIntervalSince1970: 1700000000),
      size: nil,
      url: nil  // No URL = pending
    )
    return file
  }()

  static let downloadedFile = File(
    fileId: "downloaded-file-789",
    key: "Downloaded Video.mp4",
    publishDate: Date(timeIntervalSince1970: 1699000000),
    size: 2048000,
    url: URL(string: "https://example.com/downloaded.mp4")
  )

  static let multipleFiles: [File] = [
    sampleFile,
    downloadedFile,
    File(
      fileId: "file-3",
      key: "Another Video.mp4",
      publishDate: Date(timeIntervalSince1970: 1698000000),
      size: 512000,
      url: URL(string: "https://example.com/another.mp4")
    )
  ]

  // MARK: - Users

  static let sampleUser = User(
    email: "test@example.com",
    firstName: "Test",
    identifier: "user-123",
    lastName: "User"
  )

  static let newUser = User(
    email: "new@example.com",
    firstName: "New",
    identifier: "new-user-456",
    lastName: "Person"
  )

  // MARK: - Devices

  static let sampleDevice = Device(endpointArn: "arn:aws:sns:us-west-2:123456789:endpoint/test")

  // MARK: - API Responses

  static let validLoginResponse = LoginResponse(
    body: TokenResponse(token: "test-jwt-token-valid", expiresAt: nil, sessionId: "session-123", userId: "user-123"),
    error: nil,
    requestId: "request-123"
  )

  static let loginResponseWithError = LoginResponse(
    body: nil,
    error: ErrorDetail(message: "Invalid credentials", code: "AUTH_ERROR"),
    requestId: "request-456"
  )

  static let loginResponseNilBody = LoginResponse(
    body: nil,
    error: nil,
    requestId: "request-789"
  )

  static let validFileResponse = FileResponse(
    body: FileList(contents: multipleFiles, keyCount: 3),
    error: nil,
    requestId: "request-files-123"
  )

  static let emptyFileResponse = FileResponse(
    body: FileList(contents: [], keyCount: 0),
    error: nil,
    requestId: "request-files-empty"
  )

  static let fileResponseWithError = FileResponse(
    body: nil,
    error: ErrorDetail(message: "Internal server error", code: "SERVER_ERROR"),
    requestId: "request-files-error"
  )

  static let validRegisterDeviceResponse = RegisterDeviceResponse(
    body: EndpointResponse(endpointArn: "arn:aws:sns:us-west-2:123456789:endpoint/new"),
    error: nil,
    requestId: "request-device-123"
  )

  static let validAddFileResponse = DownloadFileResponse(
    body: DownloadFileResponseDetail(status: "queued"),
    error: nil,
    requestId: "request-add-123"
  )

  // MARK: - Push Notification Payloads

  static let metadataPushPayload: [AnyHashable: Any] = [
    "aps": ["content-available": 1],
    "type": "metadata",
    "file": [
      "fileId": "push-file-123",
      "key": "Push Video.mp4",
      "publishDate": "2024-01-15",
      "size": 1500000
    ]
  ]

  static let downloadReadyPushPayload: [AnyHashable: Any] = [
    "aps": ["content-available": 1],
    "type": "download-ready",
    "fileId": "push-file-123",
    "key": "push-video.mp4",
    "url": "https://example.com/push-video.mp4",
    "size": 1500000
  ]

  // MARK: - Tokens

  static let validJwtToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTUxNjIzOTAyMn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

  static let shortToken = "short-token-for-display"

  // MARK: - Error Helpers

  struct TestNetworkError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }

    static let notConnected = TestNetworkError(message: "The Internet connection appears to be offline.")
    static let timeout = TestNetworkError(message: "The request timed out.")
    static let serverError = TestNetworkError(message: "Internal server error")
  }
}
