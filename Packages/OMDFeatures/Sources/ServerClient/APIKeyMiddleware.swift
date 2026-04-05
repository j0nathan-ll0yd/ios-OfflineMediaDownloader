import ComposableArchitecture
import Foundation
import HTTPTypes
import LoggerClient
import OpenAPIRuntime

// MARK: - CRITICAL: API Key Authentication

//
// The API key MUST be sent as a QUERY PARAMETER, not a header.
// The AWS API Gateway Lambda authorizer reads from query string `ApiKey`.

/// Middleware that adds the API key as a query parameter to all requests.
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

    if let currentPath = request.path {
      let separator = currentPath.contains("?") ? "&" : "?"
      request.path = "\(currentPath)\(separator)ApiKey=\(apiKey)"
    }

    @Dependency(\.logger) var logger
    logger.debug(.network, "APIKeyMiddleware: Added API key as query parameter to path: \(request.path ?? "nil")")

    return try await next(request, body, baseURL)
  }
}
