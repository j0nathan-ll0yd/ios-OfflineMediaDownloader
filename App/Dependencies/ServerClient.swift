import Foundation
import ComposableArchitecture
import UIKit
import APITypes
import OpenAPIURLSession

enum FileStatusFilter: String {
  case all = "all"
  case downloaded = "downloaded"
}

@DependencyClient
struct ServerClient {
  var registerDevice: @Sendable (_ token: String) async throws -> RegisterDeviceResponse
  var registerUser: @Sendable (_ userData: User, _ authorizationCode: String) async throws -> LoginResponse
  var loginUser: @Sendable (_ authorizationCode: String) async throws -> LoginResponse
  var getFiles: @Sendable (_ statusFilter: FileStatusFilter) async throws -> FileResponse
  var addFile: @Sendable (_ url: URL) async throws -> DownloadFileResponse
}

extension DependencyValues {
  var serverClient: ServerClient {
    get { self[ServerClient.self] }
    set { self[ServerClient.self] = newValue }
  }
}

enum ServerClientError: Error, Equatable {
  case internalServerError(message: String, requestId: String?, correlationId: String?)
  case unauthorized(requestId: String?, correlationId: String?)
  case badRequest(message: String, requestId: String?, correlationId: String?)
  case networkError(message: String, requestId: String?, correlationId: String?)
}

extension ServerClientError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .internalServerError(let message, _, _):
      return NSLocalizedString(message, comment: "Server error")
    case .unauthorized:
      return NSLocalizedString("Session expired - please login again", comment: "Unauthorized error")
    case .badRequest(let message, _, _):
      return NSLocalizedString(message, comment: "Bad request error")
    case .networkError(let message, _, _):
      return NSLocalizedString(message, comment: "Network error")
    }
  }

  /// The request ID for server errors, useful for debugging
  public var requestId: String? {
    switch self {
    case .internalServerError(_, let requestId, _),
         .unauthorized(let requestId, _),
         .badRequest(_, let requestId, _),
         .networkError(_, let requestId, _):
      return requestId
    }
  }

  /// The correlation ID for request tracing
  public var correlationId: String? {
    switch self {
    case .internalServerError(_, _, let correlationId),
         .unauthorized(_, let correlationId),
         .badRequest(_, _, let correlationId),
         .networkError(_, _, let correlationId):
      return correlationId
    }
  }
}

// MARK: - OpenAPI Client Factory

/// Shared pinned URLSession for all API requests
/// Certificate pinning is enforced in production, disabled for debugging if needed
private let pinnedURLSession: URLSession = {
  #if DEBUG
  // In debug mode, pinning is enabled but can be toggled for development
  return makePinnedURLSession(enforcesPinning: true)
  #else
  return makePinnedURLSession(enforcesPinning: true)
  #endif
}()

/// Creates an authenticated API client with middleware for API key and JWT token injection
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
      AuthenticationMiddleware(keychainClient: keychainClient)
    ]
  )
}

/// Creates an unauthenticated API client with only API key middleware (for login/register)
private func makeUnauthenticatedAPIClient() -> Client {
  @Dependency(\.correlationClient) var correlationClient
  @Dependency(\.logger) var logger

  return Client(
    serverURL: URL(string: Environment.basePath)!,
    transport: URLSessionTransport(configuration: .init(session: pinnedURLSession)),
    middlewares: [
      CorrelationMiddleware(correlationClient: correlationClient, logger: logger),
      APIKeyMiddleware(apiKey: Environment.apiKey)
    ]
  )
}

// MARK: - Live Implementation

extension ServerClient: DependencyKey {
  static let liveValue = ServerClient(
    registerDevice: { token in
      print("📡 ServerClient.registerDevice called")
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
      print("📡 Request body: deviceId=\(deviceId), name=\(name), systemName=\(systemName)")
      #endif

      let response = try await client.Devices_registerDevice(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      switch response {
      case .ok(let okResponse):
        print("📡 ServerClient.registerDevice HTTP status: 200")
        guard case .json(let data) = okResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }
        return RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: data.body.value1.endpointArn),
          error: nil,
          requestId: "generated"
        )

      case .created(let createdResponse):
        print("📡 ServerClient.registerDevice HTTP status: 201")
        guard case .json(let data) = createdResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }
        return RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: data.body.value1.endpointArn),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.registerDevice HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.badRequest(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .unauthorized(let errorResponse):
        print("🔒 Unauthorized response: HTTP 401")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .forbidden(let errorResponse):
        print("🔒 Forbidden response: HTTP 403")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.registerDevice HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.internalServerError(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .undocumented(let statusCode, let payload):
        print("📡 ServerClient.registerDevice HTTP status: \(statusCode)")
        let requestId = payload.headerFields[.init("x-amzn-requestid")!]
        if statusCode == 401 || statusCode == 403 {
          print("🔒 Unauthorized response: HTTP \(statusCode)")
          throw ServerClientError.unauthorized(requestId: requestId, correlationId: nil)
        }
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)", requestId: requestId, correlationId: nil)
      }
    },

    registerUser: { userData, authorizationCode in
      print("📡 ServerClient.registerUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_UserRegistrationRequest(
        idToken: authorizationCode,
        firstName: userData.firstName,
        lastName: userData.lastName
      )

      #if DEBUG
      print("📡 Request body: firstName=\(userData.firstName), lastName=\(userData.lastName)")
      #endif

      let response = try await client.Authentication_registerUser(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      switch response {
      case .ok(let okResponse):
        print("📡 ServerClient.registerUser HTTP status: 200")
        guard case .json(let data) = okResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }
        return LoginResponse(
          body: TokenResponse(token: data.body.value1.token, expiresAt: nil, sessionId: nil, userId: nil),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.registerUser HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.badRequest(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .forbidden(let errorResponse):
        print("🔒 Forbidden response: HTTP 403")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.registerUser HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.internalServerError(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .undocumented(let statusCode, let payload):
        print("📡 ServerClient.registerUser HTTP status: \(statusCode)")
        let requestId = payload.headerFields[.init("x-amzn-requestid")!]
        if statusCode == 401 || statusCode == 403 {
          print("🔒 Unauthorized response: HTTP \(statusCode)")
          throw ServerClientError.unauthorized(requestId: requestId, correlationId: nil)
        }
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)", requestId: requestId, correlationId: nil)
      }
    },

    loginUser: { authorizationCode in
      print("📡 ServerClient.loginUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_UserLoginRequest(
        idToken: authorizationCode
      )

      #if DEBUG
      print("📡 Request body: authorizationCode=\(String(authorizationCode.prefix(20)))...")
      #endif

      let response = try await client.Authentication_loginUser(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      switch response {
      case .ok(let okResponse):
        print("📡 ServerClient.loginUser HTTP status: 200")
        guard case .json(let data) = okResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }
        return LoginResponse(
          body: TokenResponse(token: data.body.value1.token, expiresAt: nil, sessionId: nil, userId: nil),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.badRequest(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .forbidden(let errorResponse):
        print("🔒 Forbidden response: HTTP 403")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .notFound(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 404")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "User not found", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.badRequest(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .conflict(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 409")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Conflict", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.badRequest(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.internalServerError(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .undocumented(let statusCode, let payload):
        print("📡 ServerClient.loginUser HTTP status: \(statusCode)")
        let requestId = payload.headerFields[.init("x-amzn-requestid")!]
        if statusCode == 401 || statusCode == 403 {
          print("🔒 Unauthorized response: HTTP \(statusCode)")
          throw ServerClientError.unauthorized(requestId: requestId, correlationId: nil)
        }
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)", requestId: requestId, correlationId: nil)
      }
    },

    getFiles: { statusFilter in
      print("📡 ServerClient.getFiles called with status filter: \(statusFilter.rawValue)")
      let client = makeAuthenticatedAPIClient()

      // TODO: Add query parameter support when backend API is deployed and OpenAPI types regenerated
      // For now, fetch files without status filter (backend returns all by default after deployment)
      let response = try await client.Files_listFiles(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey)
      )

      switch response {
      case .ok(let okResponse):
        print("📡 ServerClient.getFiles HTTP status: 200")
        guard case .json(let data) = okResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }

        // Map API files to domain File objects
        let files: [File] = data.body.value1.contents.map { apiFile in
          mapAPIFileToDomainFile(apiFile)
        }

        return FileResponse(
          body: FileList(contents: files, keyCount: Int(data.body.value1.keyCount)),
          error: nil,
          requestId: "generated"
        )

      case .unauthorized(let errorResponse):
        print("🔒 Unauthorized response: HTTP 401")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .forbidden(let errorResponse):
        print("🔒 Forbidden response: HTTP 403")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.getFiles HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.internalServerError(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .undocumented(let statusCode, let payload):
        print("📡 ServerClient.getFiles HTTP status: \(statusCode)")
        let requestId = payload.headerFields[.init("x-amzn-requestid")!]
        if statusCode == 401 || statusCode == 403 {
          print("🔒 Unauthorized response: HTTP \(statusCode)")
          throw ServerClientError.unauthorized(requestId: requestId, correlationId: nil)
        }
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)", requestId: requestId, correlationId: nil)
      }
    },

    addFile: { url in
      print("📡 ServerClient.addFile called with URL: \(url)")
      let client = makeAuthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_FeedlyWebhookRequest(
        articleTitle: "User Added", // Required field - placeholder
        articleURL: url.absoluteString
      )

      #if DEBUG
      print("📡 Request body: articleURL=\(url.absoluteString)")
      #endif

      let response = try await client.Webhooks_processFeedlyWebhook(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey),
        body: .json(requestBody)
      )

      switch response {
      case .ok(let okResponse):
        print("📡 ServerClient.addFile HTTP status: 200")
        guard case .json(let data) = okResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }
        return DownloadFileResponse(
          body: DownloadFileResponseDetail(status: data.body.value1.status.rawValue),
          error: nil,
          requestId: "generated"
        )

      case .accepted(let acceptedResponse):
        print("📡 ServerClient.addFile HTTP status: 202")
        guard case .json(let data) = acceptedResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format", requestId: nil, correlationId: nil)
        }
        return DownloadFileResponse(
          body: DownloadFileResponseDetail(status: data.body.value1.status.rawValue),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.addFile HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.badRequest(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .forbidden(let errorResponse):
        print("🔒 Forbidden response: HTTP 403")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized(requestId: nil, correlationId: nil)
        }
        throw ServerClientError.unauthorized(requestId: error.requestId, correlationId: nil)

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.addFile HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error", requestId: nil, correlationId: nil)
        }
        throw ServerClientError.internalServerError(message: "\(error.error.message)", requestId: error.requestId, correlationId: nil)

      case .undocumented(let statusCode, let payload):
        print("📡 ServerClient.addFile HTTP status: \(statusCode)")
        let requestId = payload.headerFields[.init("x-amzn-requestid")!]
        // Handle 401/403 as unauthorized even if not in OpenAPI spec
        if statusCode == 401 || statusCode == 403 {
          print("🔒 Unauthorized response: HTTP \(statusCode)")
          throw ServerClientError.unauthorized(requestId: requestId, correlationId: nil)
        }
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)", requestId: requestId, correlationId: nil)
      }
    }
  )
}

// MARK: - File Mapping

/// Maps OpenAPI file model to domain File model
private func mapAPIFileToDomainFile(_ apiFile: Components.Schemas.Models_period_File) -> File {
  // Parse date from string using shared DateFormatters
  let publishDate = apiFile.publishDate.flatMap { DateFormatters.parse($0) }

  // Map status - access the nested value1 property
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

  return file
}

// MARK: - Test/Preview implementation

extension ServerClient {
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
    }
  )
}
