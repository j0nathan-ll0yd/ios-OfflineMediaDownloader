import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Middleware that intercepts API requests and adds the API key as a query parameter
struct APIKeyMiddleware: ClientMiddleware {
  let apiKey: String

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request

    // Add API key as query parameter (backend authorizer expects ?ApiKey=xxx)
    // Modify the request path to include the query parameter
    if let currentPath = request.path {
      let separator = currentPath.contains("?") ? "&" : "?"
      request.path = "\(currentPath)\(separator)ApiKey=\(apiKey)"
    }

    print("🔑 APIKeyMiddleware: Added API key as query parameter to path: \(request.path ?? "nil")")

    return try await next(request, body, baseURL)
  }
}
