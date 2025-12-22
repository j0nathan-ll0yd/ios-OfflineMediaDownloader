import Foundation
import OpenAPIRuntime
import HTTPTypes
import ComposableArchitecture

/// Middleware that intercepts API requests and adds JWT authentication headers
struct AuthenticationMiddleware: ClientMiddleware {
  let keychainClient: KeychainClient
  
  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: HTTPTypes.HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPTypes.HTTPRequest, HTTPTypes.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPTypes.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, HTTPTypes.HTTPBody?) {
    var request = request
    
    // Add JWT token if available
    if let token = try? await keychainClient.getJwtToken() {
      request.headerFields[.authorization] = "Bearer \(token)"
      print("🔑 AuthenticationMiddleware: Added Bearer token to request")
    } else {
      print("🔑 AuthenticationMiddleware: No token available")
    }
    
    return try await next(request, body, baseURL)
  }
}
