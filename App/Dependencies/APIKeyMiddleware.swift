import Foundation
import HTTPTypes
import OpenAPIRuntime

// MARK: - ⚠️ CRITICAL: API Key Authentication ⚠️

//
// The API key MUST be sent as a QUERY PARAMETER, not a header.
//
// WHY: The AWS API Gateway Lambda authorizer is configured to read the API key
// from the query string parameter `ApiKey`. Using a header (like x-api-key)
// will result in 401/403 errors because the authorizer won't find the key.
//
// CORRECT:   ?ApiKey=xxx (query parameter)
// INCORRECT: X-API-Key: xxx (header) ← DO NOT USE
//
// This was incorrectly changed to a header in the past and caused auth failures.
// See commit 244478b for the original fix.
//
// If you're seeing 401 errors and the API key looks correct, verify this file
// is using query parameters, not headers.

/// Middleware that adds the API key as a query parameter to all requests.
///
/// - Important: The backend authorizer expects `?ApiKey=xxx` as a query parameter.
///   Do NOT change this to use headers - it will break authentication.
struct APIKeyMiddleware: ClientMiddleware {
  let apiKey: String

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID _: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request

    // ⚠️ CRITICAL: Must be query parameter, not header. See comment block above.
    if let currentPath = request.path {
      let separator = currentPath.contains("?") ? "&" : "?"
      request.path = "\(currentPath)\(separator)ApiKey=\(apiKey)"
    }

    print("🔑 APIKeyMiddleware: Added API key as query parameter to path: \(request.path ?? "nil")")

    return try await next(request, body, baseURL)
  }
}
