import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Middleware that intercepts API requests and adds the API key as an HTTP header
/// Uses x-api-key header which AWS API Gateway supports natively
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

    // Add API key as header (more secure than query params - not logged/cached)
    request.headerFields[HTTPField.Name("x-api-key")!] = apiKey

    print("🔑 APIKeyMiddleware: Added x-api-key header")

    return try await next(request, body, baseURL)
  }
}
