import ComposableArchitecture
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Middleware that intercepts API requests and adds JWT authentication headers
struct AuthenticationMiddleware: ClientMiddleware {
  let keychainClient: KeychainClient

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID _: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request

    // Add JWT token if available
    do {
      if let token = try await keychainClient.getJwtToken() {
        request.headerFields[.authorization] = "Bearer \(token)"
        let preview = String(token.prefix(20)) + "..."
        print("🔑 AuthenticationMiddleware: Added Bearer token (\(preview)) to request")
      } else {
        print("🔑 AuthenticationMiddleware: No token in keychain")
      }
    } catch {
      print("🔑 AuthenticationMiddleware: Error getting token: \(error)")
    }

    return try await next(request, body, baseURL)
  }
}
