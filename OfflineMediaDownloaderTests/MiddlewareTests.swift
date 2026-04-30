import ConcurrencyExtras
import CorrelationClient
import Foundation
import HTTPTypes
import KeychainClient
import LoggerClient
@preconcurrency import OpenAPIRuntime
@testable import ServerClient
import Testing

enum MiddlewareTests {
  /// Shared noop logger for middleware tests
  private static var noopLogger: LoggerClient {
    LoggerClient(
      log: { _, _, _, _, _, _ in },
      getRecentLogs: { _ in [] },
      clearLogs: {},
      exportLogs: { Data() },
      setMinLevel: { _ in }
    )
  }

  // MARK: - APIKeyMiddleware Tests

  struct APIKeyMiddlewareTests {
    @Test("Adds API key as query parameter to path without existing query")
    func addsApiKeyToCleanPath() async {
      let middleware = APIKeyMiddleware(apiKey: "test-api-key-123", logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/files?ApiKey=test-api-key-123")
    }

    @Test("Appends API key to path with existing query parameter")
    func appendsApiKeyToExistingQuery() async {
      let middleware = APIKeyMiddleware(apiKey: "my-secret-key", logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files?limit=10")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/files?limit=10&ApiKey=my-secret-key")
    }

    @Test("Handles special characters in API key")
    func handlesSpecialCharactersInApiKey() async {
      let middleware = APIKeyMiddleware(apiKey: "key+with=special/chars", logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/test?ApiKey=key+with=special/chars")
    }

    @Test("Works with POST requests")
    func worksWithPostRequests() async {
      let middleware = APIKeyMiddleware(apiKey: "post-key", logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/login?ApiKey=post-key")
    }

    @Test("Handles nil path gracefully")
    func handlesNilPathGracefully() async {
      let middleware = APIKeyMiddleware(apiKey: "test-key", logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: nil)
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      // Path should remain nil when it was nil
      #expect(capturedPath == nil)
    }

    /// Helper to capture the modified request path
    private func captureRequestPath(middleware: APIKeyMiddleware, request: inout HTTPRequest) async -> String? {
      let capturedPath = LockIsolated<String?>(nil)

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "test"
        ) { @Sendable modifiedRequest, _, _ in
          capturedPath.setValue(modifiedRequest.path)
          return (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore errors for this test
      }

      return capturedPath.value
    }
  }

  // MARK: - AuthenticationMiddleware Tests

  struct AuthenticationMiddlewareTests {
    @Test("Adds Bearer token header when token exists")
    func addsBearerTokenWhenExists() async {
      let testToken = "jwt-token-abc123"
      let keychainClient = KeychainClient(
        getUserData: { throw KeychainError.itemNotFound },
        getJwtToken: { testToken },
        getTokenExpiresAt: { nil },
        getDeviceData: { nil },
        getUserIdentifier: { nil },
        setUserData: { _ in },
        setJwtToken: { _ in },
        setTokenExpiresAt: { _ in },
        setDeviceData: { _ in },
        deleteUserData: {},
        deleteJwtToken: {},
        deleteTokenExpiresAt: {},
        deleteDeviceData: {}
      )

      let middleware = AuthenticationMiddleware(keychainClient: keychainClient, logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedAuthHeader = await captureAuthorizationHeader(middleware: middleware, request: &request)

      #expect(capturedAuthHeader == "Bearer jwt-token-abc123")
    }

    @Test("Does not add header when no token in keychain")
    func noHeaderWhenNoToken() async {
      let keychainClient = KeychainClient(
        getUserData: { throw KeychainError.itemNotFound },
        getJwtToken: { nil },
        getTokenExpiresAt: { nil },
        getDeviceData: { nil },
        getUserIdentifier: { nil },
        setUserData: { _ in },
        setJwtToken: { _ in },
        setTokenExpiresAt: { _ in },
        setDeviceData: { _ in },
        deleteUserData: {},
        deleteJwtToken: {},
        deleteTokenExpiresAt: {},
        deleteDeviceData: {}
      )

      let middleware = AuthenticationMiddleware(keychainClient: keychainClient, logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedAuthHeader = await captureAuthorizationHeader(middleware: middleware, request: &request)

      #expect(capturedAuthHeader == nil)
    }

    @Test("Handles keychain error gracefully")
    func handlesKeychainError() async {
      let keychainClient = KeychainClient(
        getUserData: { throw KeychainError.itemNotFound },
        getJwtToken: { throw KeychainError.unableToStore },
        getTokenExpiresAt: { nil },
        getDeviceData: { nil },
        getUserIdentifier: { nil },
        setUserData: { _ in },
        setJwtToken: { _ in },
        setTokenExpiresAt: { _ in },
        setDeviceData: { _ in },
        deleteUserData: {},
        deleteJwtToken: {},
        deleteTokenExpiresAt: {},
        deleteDeviceData: {}
      )

      let middleware = AuthenticationMiddleware(keychainClient: keychainClient, logger: MiddlewareTests.noopLogger)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedAuthHeader = await captureAuthorizationHeader(middleware: middleware, request: &request)

      // Should gracefully handle error and not add header
      #expect(capturedAuthHeader == nil)
    }

    /// Helper to capture the Authorization header from modified request
    private func captureAuthorizationHeader(middleware: AuthenticationMiddleware, request: inout HTTPRequest) async -> String? {
      let capturedHeader = LockIsolated<String?>(nil)

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "test"
        ) { @Sendable modifiedRequest, _, _ in
          capturedHeader.setValue(modifiedRequest.headerFields[.authorization])
          return (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore errors for this test
      }

      return capturedHeader.value
    }
  }

  // MARK: - CorrelationMiddleware Tests

  struct CorrelationMiddlewareTests {
    @Test("Adds X-Correlation-ID header to request")
    func addsCorrelationIdHeader() async {
      let testCorrelationId = UUID()
      let correlationClient = CorrelationClient(
        startRequest: { _, _ in testCorrelationId },
        completeRequest: { _, _, _, _ in },
        failRequest: { _, _, _ in },
        getMostRecent: { nil },
        getRecentRequests: { _ in [] },
        clearHistory: {}
      )

      let loggerClient = LoggerClient(
        log: { _, _, _, _, _, _ in },
        getRecentLogs: { _ in [] },
        clearLogs: {},
        exportLogs: { Data() },
        setMinLevel: { _ in }
      )

      let middleware = CorrelationMiddleware(correlationClient: correlationClient, logger: loggerClient)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")
      let capturedCorrelationId = await captureCorrelationIdHeader(middleware: middleware, request: &request)

      #expect(capturedCorrelationId == testCorrelationId.uuidString)
    }

    @Test("Calls completeRequest on success")
    func callsCompleteRequestOnSuccess() async throws {
      let completedCorrelationId = LockIsolated<UUID?>(nil)
      let completedStatusCode = LockIsolated<Int?>(nil)

      let testCorrelationId = UUID()
      let correlationClient = CorrelationClient(
        startRequest: { _, _ in testCorrelationId },
        completeRequest: { correlationId, statusCode, _, _ in
          completedCorrelationId.setValue(correlationId)
          completedStatusCode.setValue(statusCode)
        },
        failRequest: { _, _, _ in },
        getMostRecent: { nil },
        getRecentRequests: { _ in [] },
        clearHistory: {}
      )

      let loggerClient = LoggerClient(
        log: { _, _, _, _, _, _ in },
        getRecentLogs: { _ in [] },
        clearLogs: {},
        exportLogs: { Data() },
        setMinLevel: { _ in }
      )

      let middleware = CorrelationMiddleware(correlationClient: correlationClient, logger: loggerClient)

      let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: #require(URL(string: "https://example.com")),
          operationID: "testOperation"
        ) { @Sendable _, _, _ in
          (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore
      }

      #expect(completedCorrelationId.value == testCorrelationId)
      #expect(completedStatusCode.value == 200)
    }

    @Test("Calls failRequest on error")
    func callsFailRequestOnError() async throws {
      let failedCorrelationId = LockIsolated<UUID?>(nil)
      let failedErrorMessage = LockIsolated<String?>(nil)

      let testCorrelationId = UUID()
      let correlationClient = CorrelationClient(
        startRequest: { _, _ in testCorrelationId },
        completeRequest: { _, _, _, _ in },
        failRequest: { correlationId, errorMessage, _ in
          failedCorrelationId.setValue(correlationId)
          failedErrorMessage.setValue(errorMessage)
        },
        getMostRecent: { nil },
        getRecentRequests: { _ in [] },
        clearHistory: {}
      )

      let loggerClient = LoggerClient(
        log: { _, _, _, _, _, _ in },
        getRecentLogs: { _ in [] },
        clearLogs: {},
        exportLogs: { Data() },
        setMinLevel: { _ in }
      )

      let middleware = CorrelationMiddleware(correlationClient: correlationClient, logger: loggerClient)

      let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")

      struct TestError: Error, LocalizedError {
        var errorDescription: String? {
          "Test network failure"
        }
      }

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: #require(URL(string: "https://example.com")),
          operationID: "testOperation"
        ) { @Sendable _, _, _ in
          throw TestError()
        }
      } catch {
        // Expected to throw
      }

      #expect(failedCorrelationId.value == testCorrelationId)
      #expect(failedErrorMessage.value == "Test network failure")
    }

    /// Helper to capture the X-Correlation-ID header from modified request
    private func captureCorrelationIdHeader(middleware: CorrelationMiddleware, request: inout HTTPRequest) async -> String? {
      let capturedHeader = LockIsolated<String?>(nil)

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "test"
        ) { @Sendable modifiedRequest, _, _ in
          capturedHeader.setValue(modifiedRequest.headerFields[.init("X-Correlation-ID")!])
          return (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore errors for this test
      }

      return capturedHeader.value
    }
  }
}
