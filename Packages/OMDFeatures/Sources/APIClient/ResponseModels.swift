import Foundation
import SharedModels

// MARK: - Error Detail

public struct ErrorDetail: Codable, Sendable {
  public var message: String
  public var code: String?

  public init(message: String, code: String? = nil) {
    self.message = message
    self.code = code
  }
}

// MARK: - Login Response

public struct LoginResponse: Codable, Sendable {
  public var body: TokenResponse?
  public var error: ErrorDetail?
  public var requestId: String

  public init(body: TokenResponse? = nil, error: ErrorDetail? = nil, requestId: String) {
    self.body = body
    self.error = error
    self.requestId = requestId
  }
}

// MARK: - File Response

public struct FileResponse: Codable, Sendable {
  public var body: FileList?
  public var error: ErrorDetail?
  public var requestId: String

  public init(body: FileList? = nil, error: ErrorDetail? = nil, requestId: String) {
    self.body = body
    self.error = error
    self.requestId = requestId
  }
}

// MARK: - Download File Response

public struct DownloadFileResponseDetail: Codable, Sendable {
  public var status: String

  public init(status: String) {
    self.status = status
  }
}

public struct DownloadFileResponse: Codable, Sendable {
  public var body: DownloadFileResponseDetail?
  public var error: ErrorDetail?
  public var requestId: String

  public init(body: DownloadFileResponseDetail? = nil, error: ErrorDetail? = nil, requestId: String) {
    self.body = body
    self.error = error
    self.requestId = requestId
  }
}

// MARK: - Delete File Response

public struct DeleteFileResponseDetail: Codable, Sendable {
  public var deleted: Bool
  public var fileRemoved: Bool

  public init(deleted: Bool, fileRemoved: Bool) {
    self.deleted = deleted
    self.fileRemoved = fileRemoved
  }
}

public struct DeleteFileResponse: Codable, Sendable {
  public var body: DeleteFileResponseDetail?
  public var error: ErrorDetail?
  public var requestId: String

  public init(body: DeleteFileResponseDetail? = nil, error: ErrorDetail? = nil, requestId: String) {
    self.body = body
    self.error = error
    self.requestId = requestId
  }
}

// MARK: - Register Device Response

public struct EndpointResponse: Codable, Sendable {
  public var endpointArn: String

  public init(endpointArn: String) {
    self.endpointArn = endpointArn
  }
}

public struct RegisterDeviceResponse: Codable, Sendable {
  public var body: EndpointResponse
  public var error: ErrorDetail?
  public var requestId: String

  public init(body: EndpointResponse, error: ErrorDetail? = nil, requestId: String) {
    self.body = body
    self.error = error
    self.requestId = requestId
  }
}
