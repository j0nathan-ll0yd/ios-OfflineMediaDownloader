import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Middleware that adds correlation ID header to requests and tracks request lifecycle
struct CorrelationMiddleware: ClientMiddleware {
  let correlationClient: CorrelationClient
  let logger: LoggerClient

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request
    let startTime = Date()

    // Generate correlation ID and start tracking
    let correlationId = await correlationClient.startRequest(operationID, request.method.rawValue)
    guard let correlationIdField = HTTPField.Name("X-Correlation-ID") else {
      fatalError("X-Correlation-ID is a valid HTTP field name")
    }
    request.headerFields[correlationIdField] = correlationId.uuidString

    // Log outgoing request
    logger.info(.network, "Request started: \(operationID)", metadata: [
      "correlationId": correlationId.uuidString,
      "method": request.method.rawValue,
      "path": request.path ?? "unknown"
    ])

    do {
      let (response, responseBody) = try await next(request, body, baseURL)
      let duration = Date().timeIntervalSince(startTime)

      // Extract server request ID from response headers if present
      guard let requestIdField = HTTPField.Name("x-amzn-requestid") else {
        fatalError("x-amzn-requestid is a valid HTTP field name")
      }
      let serverRequestId = response.headerFields[requestIdField]

      // Record success
      await correlationClient.completeRequest(
        correlationId,
        response.status.code,
        duration,
        serverRequestId
      )

      // Log completion
      logger.info(.network, "Request completed: \(operationID)", metadata: [
        "correlationId": correlationId.uuidString,
        "statusCode": "\(response.status.code)",
        "duration": String(format: "%.2fs", duration),
        "serverRequestId": serverRequestId ?? "none"
      ])

      return (response, responseBody)

    } catch {
      let duration = Date().timeIntervalSince(startTime)

      // Record failure
      await correlationClient.failRequest(
        correlationId,
        error.localizedDescription,
        duration
      )

      // Log error
      logger.error(.network, "Request failed: \(operationID)", metadata: [
        "correlationId": correlationId.uuidString,
        "error": error.localizedDescription,
        "duration": String(format: "%.2fs", duration)
      ])

      throw error
    }
  }
}
