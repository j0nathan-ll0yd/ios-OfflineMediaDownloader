import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Middleware that intercepts API requests and adds the API key header
struct APIKeyMiddleware: ClientMiddleware {
  let apiKey: String
  
  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: HTTPTypes.HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPTypes.HTTPRequest, HTTPTypes.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPTypes.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, HTTPTypes.HTTPBody?) {
    var request = request
    
    // Add API key header
    request.headerFields[.init("X-API-Key")!] = apiKey
    print("🔑 APIKeyMiddleware: Added API key to request")
    
    return try await next(request, body, baseURL)
  }
}
