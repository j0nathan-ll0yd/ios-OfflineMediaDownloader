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
  public var deleteFile: @Sendable (_ fileId: String) async throws -> DeleteFileResponse
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

// MARK: - Error Mapping

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
      APIKeyMiddleware(apiKey: Environment.apiKey, logger: logger),
      AuthenticationMiddleware(keychainClient: keychainClient, logger: logger),
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
      APIKeyMiddleware(apiKey: Environment.apiKey, logger: logger),
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

      let response = try await client.postDeviceRegister(
        body: .json(requestBody)
      )

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.registerDevice succeeded")
        return RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: payload.endpointArn),
          error: nil,
          requestId: "generated"
        )
      case let .created(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.registerDevice created (201)")
        return RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: payload.endpointArn),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    registerUser: { userData, authorizationCode in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.registerUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_RegistrationRequest(
        idToken: authorizationCode,
        firstName: userData.firstName,
        lastName: userData.lastName
      )

      #if DEBUG
        logger.debug(.network, "Request body: firstName=\(userData.firstName), lastName=\(userData.lastName)")
      #endif

      let response = try await client.postUserRegister(
        body: .json(requestBody)
      )

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.registerUser succeeded")
        return LoginResponse(
          body: TokenResponse(
            token: payload.token,
            expiresAt: payload.expiresAt,
            sessionId: payload.sessionId,
            userId: payload.userId
          ),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    loginUser: { authorizationCode in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.loginUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_LoginRequest(
        idToken: authorizationCode
      )

      #if DEBUG
        logger.debug(.network, "Request body: authorizationCode=\(String(authorizationCode.prefix(20)))...")
      #endif

      let response = try await client.postUserLogin(
        body: .json(requestBody)
      )

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.loginUser succeeded")
        return LoginResponse(
          body: TokenResponse(
            token: payload.token,
            expiresAt: payload.expiresAt,
            sessionId: payload.sessionId,
            userId: payload.userId
          ),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    refreshToken: {
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.refreshToken called")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.postUserRefresh()

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.refreshToken succeeded")
        return LoginResponse(
          body: TokenResponse(
            token: payload.token,
            expiresAt: payload.expiresAt,
            sessionId: payload.sessionId,
            userId: payload.userId
          ),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .unauthorized(r):
        throw mapStatusCodeToError(401, message: nil, requestId: try? r.body.json.requestId)
      case let .forbidden(r):
        throw mapStatusCodeToError(403, message: nil, requestId: try? r.body.json.requestId)
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    getFiles: { statusFilter in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.getFiles called with status filter: \(statusFilter.rawValue)")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.getFiles(
        query: .init(status: statusFilter.rawValue)
      )

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.getFiles succeeded")
        let files: [File] = payload.contents.map { mapAPIFileListItemToDomainFile($0) }
        return FileResponse(
          body: FileList(contents: files, keyCount: Int(payload.keyCount)),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    addFile: { url in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.addFile called with URL: \(url)")
      let client = makeAuthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_FeedlyWebhookRequest(
        articleURL: url.absoluteString
      )

      #if DEBUG
        logger.debug(.network, "Request body: articleURL=\(url.absoluteString)")
      #endif

      let response = try await client.postFeedlyWebhook(
        body: .json(requestBody)
      )

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.addFile succeeded")
        // WebhookResponse.status is a oneOf union with three possible literal values:
        // Dispatched (value1), Initiated (value2), Accepted (value3).
        let statusString = payload.status.value1?.rawValue
          ?? payload.status.value2?.rawValue
          ?? payload.status.value3?.rawValue
          ?? "unknown"
        return DownloadFileResponse(
          body: DownloadFileResponseDetail(status: statusString),
          error: nil,
          requestId: "generated"
        )
      case let .accepted(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.addFile accepted (202)")
        let statusString = payload.status.value1?.rawValue
          ?? payload.status.value2?.rawValue
          ?? payload.status.value3?.rawValue
          ?? "Accepted"
        return DownloadFileResponse(
          body: DownloadFileResponseDetail(status: statusString),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .unauthorized(r):
        throw mapStatusCodeToError(401, message: nil, requestId: try? r.body.json.requestId)
      case let .forbidden(r):
        throw mapStatusCodeToError(403, message: nil, requestId: try? r.body.json.requestId)
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    deleteFile: { fileId in
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.deleteFile called with fileId: \(fileId)")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.deleteFilesByFileId(
        path: .init(fileId: fileId)
      )

      switch response {
      case let .ok(r):
        let payload = try r.body.json
        logger.info(.network, "ServerClient.deleteFile succeeded")
        return DeleteFileResponse(
          body: DeleteFileResponseDetail(
            deleted: payload.deleted,
            fileRemoved: payload.fileRemoved
          ),
          error: nil,
          requestId: "generated"
        )
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .unauthorized(r):
        throw mapStatusCodeToError(401, message: nil, requestId: try? r.body.json.requestId)
      case let .forbidden(r):
        throw mapStatusCodeToError(403, message: nil, requestId: try? r.body.json.requestId)
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    },

    logoutUser: {
      @Dependency(\.logger) var logger
      logger.info(.network, "ServerClient.logoutUser called")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.postUserLogout()

      switch response {
      case .ok:
        logger.info(.network, "ServerClient.logoutUser succeeded")
        return
      case .noContent:
        logger.info(.network, "ServerClient.logoutUser succeeded (204)")
        return
      case let .badRequest(r):
        throw mapStatusCodeToError(
          400,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .unauthorized(r):
        throw mapStatusCodeToError(401, message: nil, requestId: try? r.body.json.requestId)
      case let .forbidden(r):
        throw mapStatusCodeToError(403, message: nil, requestId: try? r.body.json.requestId)
      case let .internalServerError(r):
        throw mapStatusCodeToError(
          500,
          message: (try? r.body.json.error.message).map { "\($0)" },
          requestId: try? r.body.json.requestId
        )
      case let .undocumented(code, p):
        throw mapStatusCodeToError(code, message: nil, requestId: p.headerFields[.init("x-amzn-requestid")!])
      }
    }
  )
}

// MARK: - File Mapping

/// Maps an item from the `/files` list response to the domain `File` model.
///
/// The CLI's $ref promotion resolves `FileListResponse.contents` items to the
/// top-level `Models.File` component, so this takes `Models_period_File` directly.
private func mapAPIFileListItemToDomainFile(
  _ apiFile: Components.Schemas.Models_period_File
) -> File {
  let publishDate = apiFile.publishDate.flatMap { DateFormatters.parse($0) }

  // The nested `statusPayload` enum has identical raw values to the domain
  // `FileStatus` enum, so map via rawValue to stay independent of the
  // generator's naming.
  let fileStatus: FileStatus? = apiFile.status.flatMap { FileStatus(rawValue: $0.rawValue) }

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
    deleteFile: { _ in
      DeleteFileResponse(
        body: DeleteFileResponseDetail(deleted: true, fileRemoved: true),
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
    deleteFile: { _ in
      DeleteFileResponse(
        body: DeleteFileResponseDetail(deleted: true, fileRemoved: true),
        error: nil,
        requestId: "preview"
      )
    },
    logoutUser: {}
  )
}
