import APIClient
import APITypes
import ComposableArchitecture
import CorrelationClient
import Foundation
import KeychainClient
import LoggerClient
import OpenAPIURLSession
import SharedModels
import UIKit

public enum FileStatusFilter: String, Sendable {
  case all
  case downloaded
}

@DependencyClient
public struct ServerClient: Sendable {
  public var registerDevice: @Sendable (_ token: String) async throws -> RegisterDeviceResponse
  public var registerUser: @Sendable (_ userData: User, _ authorizationCode: String) async throws -> LoginResponse
  public var loginUser: @Sendable (_ authorizationCode: String) async throws -> LoginResponse
  public var refreshToken: @Sendable () async throws -> LoginResponse
  public var getFiles: @Sendable (_ statusFilter: FileStatusFilter) async throws -> FileResponse
  public var addFile: @Sendable (_ url: URL) async throws -> DownloadFileResponse
  public var logoutUser: @Sendable () async throws -> Void
}

public extension DependencyValues {
  var serverClient: ServerClient {
    get { self[ServerClient.self] }
    set { self[ServerClient.self] = newValue }
  }
}

public enum ServerClientError: Error, Equatable {
  case internalServerError(message: String, requestId: String?, correlationId: String?)
  case unauthorized(requestId: String?, correlationId: String?)
  case badRequest(message: String, requestId: String?, correlationId: String?)
  case networkError(message: String, requestId: String?, correlationId: String?)
}

extension ServerClientError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case let .internalServerError(message, _, _):
      NSLocalizedString(message, comment: "Server error")
    case .unauthorized:
      NSLocalizedString("Session expired - please login again", comment: "Unauthorized error")
    case let .badRequest(message, _, _):
      NSLocalizedString(message, comment: "Bad request error")
    case let .networkError(message, _, _):
      NSLocalizedString(message, comment: "Network error")
    }
  }

  public var requestId: String? {
    switch self {
    case let .internalServerError(_, requestId, _),
         let .unauthorized(requestId, _),
         let .badRequest(_, requestId, _),
         let .networkError(_, requestId, _):
      requestId
    }
  }

  public var correlationId: String? {
    switch self {
    case let .internalServerError(_, _, correlationId),
         let .unauthorized(_, correlationId),
         let .badRequest(_, _, correlationId),
         let .networkError(_, _, correlationId):
      correlationId
    }
  }
}

// MARK: - Generic Response Handling

/// Generic handler for OpenAPI responses that extracts success/error and maps to domain types
private func handleAPIResponse<SuccessPayload, DomainResponse>(
  endpoint: String,
  successExtractor: () -> SuccessPayload?,
  errorExtractor: () -> (statusCode: Int, message: String?, requestId: String?)?,
  transform: (SuccessPayload) throws -> DomainResponse
) throws -> DomainResponse {
  @Dependency(\.logger) var logger
  if let payload = successExtractor() {
    logger.info(.network, "ServerClient.\(endpoint) succeeded")
    return try transform(payload)
  }

  if let (statusCode, message, requestId) = errorExtractor() {
    logger.warning(.network, "ServerClient.\(endpoint) failed: HTTP \(statusCode)")
    throw mapStatusCodeToError(statusCode, message: message, requestId: requestId)
  }

  throw ServerClientError.networkError(message: "Unexpected response", requestId: nil, correlationId: nil)
}

/// Centralized error mapping from HTTP status codes
private func mapStatusCodeToError(
  _ statusCode: Int,
  message: String?,
  requestId: String?
) -> ServerClientError {
  switch statusCode {
  case 400:
    .badRequest(message: message ?? "Bad request", requestId: requestId, correlationId: nil)
  case 401, 403:
    .unauthorized(requestId: requestId, correlationId: nil)
  case 404:
    .badRequest(message: message ?? "Not found", requestId: requestId, correlationId: nil)
  case 409:
    .badRequest(message: message ?? "Conflict", requestId: requestId, correlationId: nil)
  case 500 ... 599:
    .internalServerError(message: message ?? "Server error", requestId: requestId, correlationId: nil)
  default:
    .networkError(message: "HTTP \(statusCode)", requestId: requestId, correlationId: nil)
  }
}

// MARK: - OpenAPI Client Factory

private let pinnedURLSession: URLSession = {
  #if DEBUG
    return makePinnedURLSession(enforcesPinning: true)
  #else
    return makePinnedURLSession(enforcesPinning: true)
  #endif
}()

private func makeAuthenticatedAPIClient() -> Client {
  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.correlationClient) var correlationClient
  @Dependency(\.logger) var logger

  return Client(
    serverURL: URL(string: Environment.basePath)!,
    transport: URLSessionTransport(configuration: .init(session: pinnedURLSession)),
    middlewares: [
      CorrelationMiddleware(correlationClient: correlationClient, logger: logger),
      APIKeyMiddleware(apiKey: Environment.apiKey),
      AuthenticationMiddleware(keychainClient: keychainClient),
    ]
  )
}

private func makeUnauthenticatedAPIClient() -> Client {
  @Dependency(\.correlationClient) var correlationClient
  @Dependency(\.logger) var logger

  return Client(
    serverURL: URL(string: Environment.basePath)!,
    transport: URLSessionTransport(configuration: .init(session: pinnedURLSession)),
    middlewares: [
      CorrelationMiddleware(correlationClient: correlationClient, logger: logger),
      APIKeyMiddleware(apiKey: Environment.apiKey),
    ]
  )
}

// MARK: - Live Implementation

extension ServerClient: DependencyKey {
  public static let liveValue = ServerClient(
    registerDevice: { token in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.registerDevice called")
      let client = makeAuthenticatedAPIClient()

      let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? ""
      let name = await UIDevice.current.name
      let systemName = await UIDevice.current.systemName
      let systemVersion = await UIDevice.current.systemVersion

      let requestBody = Components.Schemas.Models_period_DeviceRegistrationRequest(
        deviceId: deviceId,
        name: name,
        systemName: systemName,
        systemVersion: systemVersion,
        token: token
      )

      #if DEBUG
        logger.debug(.network, "Request body: deviceId=\(deviceId), name=\(name), systemName=\(systemName)")
      #endif

      let response = try await client.Devices_registerDevice(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      return try handleAPIResponse(
        endpoint: "registerDevice",
        successExtractor: {
          switch response {
          case let .ok(r): try? r.body.json.body.value1
          case let .created(r): try? r.body.json.body.value1
          default: nil
          }
        },
        errorExtractor: {
          switch response {
          case let .badRequest(r): (400, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .unauthorized(r): (401, nil, try? r.body.json.requestId)
          case let .forbidden(r): (403, nil, try? r.body.json.requestId)
          case let .internalServerError(r): (500, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .undocumented(code, p): (code, nil, p.headerFields[.init("x-amzn-requestid")!])
          default: nil
          }
        },
        transform: { (response: Components.Schemas.Models_period_DeviceRegistrationResponse) in
          RegisterDeviceResponse(
            body: EndpointResponse(endpointArn: response.endpointArn),
            error: nil,
            requestId: "generated"
          )
        }
      )
    },

    registerUser: { userData, authorizationCode in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.registerUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_UserRegistrationRequest(
        idToken: authorizationCode,
        firstName: userData.firstName,
        lastName: userData.lastName
      )

      #if DEBUG
        logger.debug(.network, "Request body: firstName=\(userData.firstName), lastName=\(userData.lastName)")
      #endif

      let response = try await client.Authentication_registerUser(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      return try handleAPIResponse(
        endpoint: "registerUser",
        successExtractor: {
          switch response {
          case let .ok(r): try? r.body.json.body.value1
          default: nil
          }
        },
        errorExtractor: {
          switch response {
          case let .badRequest(r): (400, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .forbidden(r): (403, nil, try? r.body.json.requestId)
          case let .internalServerError(r): (500, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .undocumented(code, p): (code, nil, p.headerFields[.init("x-amzn-requestid")!])
          default: nil
          }
        },
        transform: { (response: Components.Schemas.Models_period_UserRegistrationResponse) in
          LoginResponse(
            body: TokenResponse(
              token: response.token,
              expiresAt: response.expiresAt,
              sessionId: response.sessionId,
              userId: response.userId
            ),
            error: nil,
            requestId: "generated"
          )
        }
      )
    },

    loginUser: { authorizationCode in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.loginUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_UserLoginRequest(
        idToken: authorizationCode
      )

      #if DEBUG
        logger.debug(.network, "Request body: authorizationCode=\(String(authorizationCode.prefix(20)))...")
      #endif

      let response = try await client.Authentication_loginUser(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      return try handleAPIResponse(
        endpoint: "loginUser",
        successExtractor: {
          switch response {
          case let .ok(r): try? r.body.json.body.value1
          default: nil
          }
        },
        errorExtractor: {
          switch response {
          case let .badRequest(r): (400, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .forbidden(r): (403, nil, try? r.body.json.requestId)
          case let .notFound(r): (404, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .conflict(r): (409, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .internalServerError(r): (500, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .undocumented(code, p): (code, nil, p.headerFields[.init("x-amzn-requestid")!])
          default: nil
          }
        },
        transform: { (response: Components.Schemas.Models_period_UserLoginResponse) in
          LoginResponse(
            body: TokenResponse(
              token: response.token,
              expiresAt: response.expiresAt,
              sessionId: response.sessionId,
              userId: response.userId
            ),
            error: nil,
            requestId: "generated"
          )
        }
      )
    },

    refreshToken: {
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.refreshToken called")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.Authentication_refreshToken(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey)
      )

      return try handleAPIResponse(
        endpoint: "refreshToken",
        successExtractor: {
          switch response {
          case let .ok(r): try? r.body.json.body.value1
          default: nil
          }
        },
        errorExtractor: {
          switch response {
          case let .unauthorized(r): (401, nil, try? r.body.json.requestId)
          case let .internalServerError(r): (500, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .undocumented(code, p): (code, nil, p.headerFields[.init("x-amzn-requestid")!])
          default: nil
          }
        },
        transform: { (response: Components.Schemas.Models_period_TokenRefreshResponse) in
          LoginResponse(
            body: TokenResponse(
              token: response.token,
              expiresAt: response.expiresAt,
              sessionId: response.sessionId,
              userId: response.userId
            ),
            error: nil,
            requestId: "generated"
          )
        }
      )
    },

    getFiles: { statusFilter in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.getFiles called with status filter: \(statusFilter.rawValue)")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.Files_listFiles(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey)
      )

      return try handleAPIResponse(
        endpoint: "getFiles",
        successExtractor: {
          switch response {
          case let .ok(r): try? r.body.json.body.value1
          default: nil
          }
        },
        errorExtractor: {
          switch response {
          case let .unauthorized(r): (401, nil, try? r.body.json.requestId)
          case let .forbidden(r): (403, nil, try? r.body.json.requestId)
          case let .internalServerError(r): (500, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .undocumented(code, p): (code, nil, p.headerFields[.init("x-amzn-requestid")!])
          default: nil
          }
        },
        transform: { (response: Components.Schemas.Models_period_FileListResponse) in
          let files: [File] = response.contents.map { mapAPIFileToDomainFile($0) }
          return FileResponse(
            body: FileList(contents: files, keyCount: Int(response.keyCount)),
            error: nil,
            requestId: "generated"
          )
        }
      )
    },

    addFile: { url in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.addFile called with URL: \(url)")
      let client = makeAuthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_FeedlyWebhookRequest(
        articleTitle: "User Added",
        articleURL: url.absoluteString
      )

      #if DEBUG
        logger.debug(.network, "Request body: articleURL=\(url.absoluteString)")
      #endif

      let response = try await client.Webhooks_processFeedlyWebhook(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      return try handleAPIResponse(
        endpoint: "addFile",
        successExtractor: {
          switch response {
          case let .ok(r): try? r.body.json.body.value1
          case let .accepted(r): try? r.body.json.body.value1
          default: nil
          }
        },
        errorExtractor: {
          switch response {
          case let .badRequest(r): (400, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .forbidden(r): (403, nil, try? r.body.json.requestId)
          case let .internalServerError(r): (500, (try? r.body.json.error.message).map { "\($0)" }, try? r.body.json.requestId)
          case let .undocumented(code, p): (code, nil, p.headerFields[.init("x-amzn-requestid")!])
          default: nil
          }
        },
        transform: { (response: Components.Schemas.Models_period_WebhookResponse) in
          DownloadFileResponse(
            body: DownloadFileResponseDetail(status: response.status.rawValue),
            error: nil,
            requestId: "generated"
          )
        }
      )
    },

    logoutUser: {
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.logoutUser called")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.Authentication_logoutUser(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey)
      )

      switch response {
      case .noContent:
        logger.info(.network, "ServerClient.logoutUser succeeded")
        return
      case let .unauthorized(r):
        throw mapStatusCodeToError(401, message: nil, requestId: try? r.body.json.requestId)
      case let .internalServerError(r):
        throw mapStatusCodeToError(500, message: (try? r.body.json.error.message).map { "\($0)" }, requestId: try? r.body.json.requestId)
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    }
  )
}

// MARK: - File Mapping

/// Maps OpenAPI file model to domain File model
private func mapAPIFileToDomainFile(_ apiFile: Components.Schemas.Models_period_File) -> File {
  let publishDate = apiFile.publishDate.flatMap { DateFormatters.parse($0) }

  var fileStatus: FileStatus?
  if let statusPayload = apiFile.status {
    switch statusPayload.value1 {
    case .Queued:
      fileStatus = .queued
    case .Downloading:
      fileStatus = .downloading
    case .Downloaded:
      fileStatus = .downloaded
    case .Failed:
      fileStatus = .failed
    }
  }

  var file = File(
    fileId: apiFile.fileId,
    key: apiFile.key ?? apiFile.fileId,
    publishDate: publishDate,
    size: apiFile.size.map { Int($0) },
    url: apiFile.url.flatMap { URL(string: $0) }
  )
  file.authorName = apiFile.authorName
  file.authorUser = apiFile.authorUser
  file.contentType = apiFile.contentType
  file.description = apiFile.description
  file.status = fileStatus
  file.title = apiFile.title
  file.duration = apiFile.duration.map { Int($0) }
  file.uploadDate = apiFile.uploadDate
  file.viewCount = apiFile.viewCount.map { Int($0) }
  file.thumbnailUrl = apiFile.thumbnailUrl

  return file
}

// MARK: - Test/Preview implementation

public extension ServerClient {
  static let testValue = ServerClient(
    registerDevice: { _ in
      RegisterDeviceResponse(
        body: EndpointResponse(endpointArn: "test-endpoint-arn"),
        error: nil,
        requestId: "test-request-id"
      )
    },
    registerUser: { _, _ in
      LoginResponse(
        body: TokenResponse(token: "test-jwt-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "test-request-id"
      )
    },
    loginUser: { _ in
      LoginResponse(
        body: TokenResponse(token: "test-jwt-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "test-request-id"
      )
    },
    refreshToken: {
      LoginResponse(
        body: TokenResponse(
          token: "refreshed-test-jwt-token",
          expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
          sessionId: "test-session",
          userId: "test-user"
        ),
        error: nil,
        requestId: "test-request-id"
      )
    },
    getFiles: { _ in
      FileResponse(
        body: FileList(contents: [], keyCount: 0),
        error: nil,
        requestId: "test-request-id"
      )
    },
    addFile: { _ in
      DownloadFileResponse(
        body: DownloadFileResponseDetail(status: "queued"),
        error: nil,
        requestId: "test-request-id"
      )
    },
    logoutUser: {}
  )

  static let previewValue = ServerClient(
    registerDevice: { _ in
      RegisterDeviceResponse(
        body: EndpointResponse(endpointArn: "preview-endpoint"),
        error: nil,
        requestId: "preview"
      )
    },
    registerUser: { _, _ in
      LoginResponse(
        body: TokenResponse(token: "preview-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "preview"
      )
    },
    loginUser: { _ in
      LoginResponse(
        body: TokenResponse(token: "preview-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "preview"
      )
    },
    refreshToken: {
      LoginResponse(
        body: TokenResponse(token: "preview-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "preview"
      )
    },
    getFiles: { _ in
      FileResponse(
        body: FileList(contents: [], keyCount: 0),
        error: nil,
        requestId: "preview"
      )
    },
    addFile: { _ in
      DownloadFileResponse(
        body: DownloadFileResponseDetail(status: "queued"),
        error: nil,
        requestId: "preview"
      )
    },
    logoutUser: {}
  )
}
