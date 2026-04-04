import Foundation
import OpenAPIRuntime
import HTTPTypes
import ComposableArchitecture
import KeychainClient
import LoggerClient

/// Middleware that intercepts API requests and adds JWT authentication headers
struct AuthenticationMiddleware: ClientMiddleware {
  let keychainClient: KeychainClient

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request

    @Dependency(\.logger) var logger
    do {
      if let token = try await keychainClient.getJwtToken() {
        request.headerFields[.authorization] = "Bearer \(token)"
        let preview = String(token.prefix(20)) + "..."
        logger.debug(.auth, "AuthenticationMiddleware: Added Bearer token (\(preview)) to request")
      } else {
        logger.debug(.auth, "AuthenticationMiddleware: No token in keychain")
      }
    } catch {
      logger.warning(.auth, "AuthenticationMiddleware: Error getting token: \(error)")
    }

    return try await next(request, body, baseURL)
  }
}
