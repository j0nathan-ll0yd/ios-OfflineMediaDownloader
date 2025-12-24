import Foundation
import ComposableArchitecture
import UIKit
import APITypes
import OpenAPIURLSession

@DependencyClient
struct ServerClient {
  var registerDevice: @Sendable (_ token: String) async throws -> RegisterDeviceResponse
  var registerUser: @Sendable (_ userData: User, _ authorizationCode: String) async throws -> LoginResponse
  var loginUser: @Sendable (_ authorizationCode: String) async throws -> LoginResponse
  var getFiles: @Sendable () async throws -> FileResponse
  var addFile: @Sendable (_ url: URL) async throws -> DownloadFileResponse
}

extension DependencyValues {
  var serverClient: ServerClient {
    get { self[ServerClient.self] }
    set { self[ServerClient.self] = newValue }
  }
}

enum ServerClientError: Error, Equatable {
  case internalServerError(message: String)
  case unauthorized
  case badRequest(message: String)
  case networkError(message: String)
}

extension ServerClientError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .internalServerError(let message):
      return NSLocalizedString(message, comment: "Server error")
    case .unauthorized:
      return NSLocalizedString("Session expired - please login again", comment: "Unauthorized error")
    case .badRequest(let message):
      return NSLocalizedString(message, comment: "Bad request error")
    case .networkError(let message):
      return NSLocalizedString(message, comment: "Network error")
    }
  }
}

// MARK: - OpenAPI Client Factory

/// Creates an authenticated API client with middleware for API key and JWT token injection
private func makeAuthenticatedAPIClient() -> Client {
  @Dependency(\.keychainClient) var keychainClient

  return Client(
    serverURL: URL(string: Environment.basePath)!,
    transport: URLSessionTransport(),
    middlewares: [
      APIKeyMiddleware(apiKey: Environment.apiKey),
      AuthenticationMiddleware(keychainClient: keychainClient)
    ]
  )
}

/// Creates an unauthenticated API client with only API key middleware (for login/register)
private func makeUnauthenticatedAPIClient() -> Client {
  Client(
    serverURL: URL(string: Environment.basePath)!,
    transport: URLSessionTransport(),
    middlewares: [
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
          throw ServerClientError.networkError(message: "Invalid response format")
        }
        return RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: data.endpointArn),
          error: nil,
          requestId: "generated"
        )

      case .created(let createdResponse):
        print("📡 ServerClient.registerDevice HTTP status: 201")
        guard case .json(let data) = createdResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format")
        }
        return RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: data.endpointArn),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.registerDevice HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request")
        }
        throw ServerClientError.badRequest(message: error.error.message)

      case .unauthorized(let errorResponse):
        print("🔒 Unauthorized response: HTTP 401")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized
        }
        if error.error.message.contains("not authorized") || error.error.message.contains("Unauthenticated") {
          throw ServerClientError.unauthorized
        }
        throw ServerClientError.unauthorized

      case .forbidden:
        print("🔒 Forbidden response: HTTP 403")
        throw ServerClientError.unauthorized

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.registerDevice HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error")
        }
        throw ServerClientError.internalServerError(message: error.error.message)

      case .undocumented(let statusCode, _):
        print("📡 ServerClient.registerDevice HTTP status: \(statusCode)")
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)")
      }
    },

    registerUser: { userData, authorizationCode in
      print("📡 ServerClient.registerUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_UserRegistration(
        authorizationCode: authorizationCode,
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
          throw ServerClientError.networkError(message: "Invalid response format")
        }
        return LoginResponse(
          body: TokenResponse(token: data.token, expiresAt: nil, sessionId: nil, userId: nil),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.registerUser HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request")
        }
        throw ServerClientError.badRequest(message: error.error.message)

      case .forbidden:
        print("🔒 Forbidden response: HTTP 403")
        throw ServerClientError.unauthorized

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.registerUser HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error")
        }
        throw ServerClientError.internalServerError(message: error.error.message)

      case .undocumented(let statusCode, _):
        print("📡 ServerClient.registerUser HTTP status: \(statusCode)")
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)")
      }
    },

    loginUser: { authorizationCode in
      print("📡 ServerClient.loginUser called")
      let client = makeUnauthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_UserLogin(
        authorizationCode: authorizationCode
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
          throw ServerClientError.networkError(message: "Invalid response format")
        }
        return LoginResponse(
          body: TokenResponse(token: data.token, expiresAt: nil, sessionId: nil, userId: nil),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request")
        }
        throw ServerClientError.badRequest(message: error.error.message)

      case .forbidden:
        print("🔒 Forbidden response: HTTP 403")
        throw ServerClientError.unauthorized

      case .notFound(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 404")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "User not found")
        }
        throw ServerClientError.badRequest(message: error.error.message)

      case .conflict(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 409")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Conflict")
        }
        throw ServerClientError.badRequest(message: error.error.message)

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.loginUser HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error")
        }
        throw ServerClientError.internalServerError(message: error.error.message)

      case .undocumented(let statusCode, _):
        print("📡 ServerClient.loginUser HTTP status: \(statusCode)")
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)")
      }
    },

    getFiles: {
      print("📡 ServerClient.getFiles called")
      let client = makeAuthenticatedAPIClient()

      let response = try await client.Files_listFiles(
        headers: .init(X_hyphen_API_hyphen_Key: Environment.apiKey)
      )

      switch response {
      case .ok(let okResponse):
        print("📡 ServerClient.getFiles HTTP status: 200")
        guard case .json(let data) = okResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format")
        }

        // Map API files to domain File objects
        let files: [File] = data.contents.map { apiFile in
          mapAPIFileToDomainFile(apiFile)
        }

        return FileResponse(
          body: FileList(contents: files, keyCount: Int(data.keyCount)),
          error: nil,
          requestId: "generated"
        )

      case .unauthorized(let errorResponse):
        print("🔒 Unauthorized response: HTTP 401")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.unauthorized
        }
        if error.error.message.contains("not authorized") || error.error.message.contains("Unauthenticated") {
          throw ServerClientError.unauthorized
        }
        throw ServerClientError.unauthorized

      case .forbidden:
        print("🔒 Forbidden response: HTTP 403")
        throw ServerClientError.unauthorized

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.getFiles HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error")
        }
        throw ServerClientError.internalServerError(message: error.error.message)

      case .undocumented(let statusCode, _):
        print("📡 ServerClient.getFiles HTTP status: \(statusCode)")
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)")
      }
    },

    addFile: { url in
      print("📡 ServerClient.addFile called with URL: \(url)")
      let client = makeAuthenticatedAPIClient()

      let requestBody = Components.Schemas.Models_period_FeedlyWebhook(
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
          throw ServerClientError.networkError(message: "Invalid response format")
        }
        return DownloadFileResponse(
          body: DownloadFileResponseDetail(status: data.status.rawValue),
          error: nil,
          requestId: "generated"
        )

      case .accepted(let acceptedResponse):
        print("📡 ServerClient.addFile HTTP status: 202")
        guard case .json(let data) = acceptedResponse.body else {
          throw ServerClientError.networkError(message: "Invalid response format")
        }
        return DownloadFileResponse(
          body: DownloadFileResponseDetail(status: data.status.rawValue),
          error: nil,
          requestId: "generated"
        )

      case .badRequest(let errorResponse):
        print("📡 ServerClient.addFile HTTP status: 400")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.badRequest(message: "Bad request")
        }
        throw ServerClientError.badRequest(message: error.error.message)

      case .forbidden:
        print("🔒 Forbidden response: HTTP 403")
        throw ServerClientError.unauthorized

      case .internalServerError(let errorResponse):
        print("📡 ServerClient.addFile HTTP status: 500")
        guard case .json(let error) = errorResponse.body else {
          throw ServerClientError.internalServerError(message: "Internal server error")
        }
        throw ServerClientError.internalServerError(message: error.error.message)

      case .undocumented(let statusCode, _):
        print("📡 ServerClient.addFile HTTP status: \(statusCode)")
        throw ServerClientError.networkError(message: "Unexpected response: \(statusCode)")
      }
    }
  )
}

// MARK: - File Mapping

/// Maps OpenAPI file model to domain File model
private func mapAPIFileToDomainFile(_ apiFile: Components.Schemas.Models_period_File) -> File {
  // Parse date from string
  var publishDate: Date?
  if let dateString = apiFile.publishDate {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    publishDate = formatter.date(from: dateString)

    // Try ISO format if YYYYMMDD fails
    if publishDate == nil {
      formatter.dateFormat = "yyyy-MM-dd"
      publishDate = formatter.date(from: dateString)
    }
  }

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
    getFiles: {
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
