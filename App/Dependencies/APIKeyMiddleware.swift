import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Middleware that intercepts API requests and adds the API key header
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

    // Add API key header
    request.headerFields[.init("X-API-Key")!] = apiKey
    print("🔑 APIKeyMiddleware: Added API key to request")

    return try await next(request, body, baseURL)
  }
}
