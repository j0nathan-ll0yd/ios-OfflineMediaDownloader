import Foundation
import Testing
import HTTPTypes
import OpenAPIRuntime
@testable import OfflineMediaDownloader

@Suite("Middleware Tests")
struct MiddlewareTests {

  // MARK: - APIKeyMiddleware Tests

  @Suite("APIKeyMiddleware")
  struct APIKeyMiddlewareTests {

    @Test("Adds API key as query parameter to path without existing query")
    func addsApiKeyToCleanPath() async throws {
      let middleware = APIKeyMiddleware(apiKey: "test-api-key-123")

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/files?ApiKey=test-api-key-123")
    }

    @Test("Appends API key to path with existing query parameter")
    func appendsApiKeyToExistingQuery() async throws {
      let middleware = APIKeyMiddleware(apiKey: "my-secret-key")

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files?limit=10")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/files?limit=10&ApiKey=my-secret-key")
    }

    @Test("Handles special characters in API key")
    func handlesSpecialCharactersInApiKey() async throws {
      let middleware = APIKeyMiddleware(apiKey: "key+with=special/chars")

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/test?ApiKey=key+with=special/chars")
    }

    @Test("Works with POST requests")
    func worksWithPostRequests() async throws {
      let middleware = APIKeyMiddleware(apiKey: "post-key")

      var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      #expect(capturedPath == "/api/login?ApiKey=post-key")
    }

    @Test("Handles nil path gracefully")
    func handlesNilPathGracefully() async throws {
      let middleware = APIKeyMiddleware(apiKey: "test-key")

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: nil)
      let capturedPath = await captureRequestPath(middleware: middleware, request: &request)

      // Path should remain nil when it was nil
      #expect(capturedPath == nil)
    }

    // Helper to capture the modified request path
    private func captureRequestPath(middleware: APIKeyMiddleware, request: inout HTTPRequest) async -> String? {
      var capturedPath: String?

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "test"
        ) { modifiedRequest, _, _ in
          capturedPath = modifiedRequest.path
          return (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore errors for this test
      }

      return capturedPath
    }
  }

  // MARK: - AuthenticationMiddleware Tests

  @Suite("AuthenticationMiddleware")
  struct AuthenticationMiddlewareTests {

    @Test("Adds Bearer token header when token exists")
    func addsBearerTokenWhenExists() async throws {
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
        deleteUserData: { },
        deleteJwtToken: { },
        deleteTokenExpiresAt: { },
        deleteDeviceData: { }
      )

      let middleware = AuthenticationMiddleware(keychainClient: keychainClient)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedAuthHeader = await captureAuthorizationHeader(middleware: middleware, request: &request)

      #expect(capturedAuthHeader == "Bearer jwt-token-abc123")
    }

    @Test("Does not add header when no token in keychain")
    func noHeaderWhenNoToken() async throws {
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
        deleteUserData: { },
        deleteJwtToken: { },
        deleteTokenExpiresAt: { },
        deleteDeviceData: { }
      )

      let middleware = AuthenticationMiddleware(keychainClient: keychainClient)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedAuthHeader = await captureAuthorizationHeader(middleware: middleware, request: &request)

      #expect(capturedAuthHeader == nil)
    }

    @Test("Handles keychain error gracefully")
    func handlesKeychainError() async throws {
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
        deleteUserData: { },
        deleteJwtToken: { },
        deleteTokenExpiresAt: { },
        deleteDeviceData: { }
      )

      let middleware = AuthenticationMiddleware(keychainClient: keychainClient)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/files")
      let capturedAuthHeader = await captureAuthorizationHeader(middleware: middleware, request: &request)

      // Should gracefully handle error and not add header
      #expect(capturedAuthHeader == nil)
    }

    // Helper to capture the Authorization header from modified request
    private func captureAuthorizationHeader(middleware: AuthenticationMiddleware, request: inout HTTPRequest) async -> String? {
      var capturedHeader: String?

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "test"
        ) { modifiedRequest, _, _ in
          capturedHeader = modifiedRequest.headerFields[.authorization]
          return (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore errors for this test
      }

      return capturedHeader
    }
  }

  // MARK: - CorrelationMiddleware Tests

  @Suite("CorrelationMiddleware")
  struct CorrelationMiddlewareTests {

    @Test("Adds X-Correlation-ID header to request")
    func addsCorrelationIdHeader() async throws {
      let testCorrelationId = UUID()
      let correlationClient = CorrelationClient(
        startRequest: { _, _ in testCorrelationId },
        completeRequest: { _, _, _, _ in },
        failRequest: { _, _, _ in },
        getMostRecent: { nil },
        getRecentRequests: { _ in [] },
        clearHistory: { }
      )

      let loggerClient = LoggerClient(
        log: { _, _, _, _, _, _ in },
        getRecentLogs: { _ in [] },
        clearLogs: { },
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
      var completedCorrelationId: UUID?
      var completedStatusCode: Int?

      let testCorrelationId = UUID()
      let correlationClient = CorrelationClient(
        startRequest: { _, _ in testCorrelationId },
        completeRequest: { correlationId, statusCode, _, _ in
          completedCorrelationId = correlationId
          completedStatusCode = statusCode
        },
        failRequest: { _, _, _ in },
        getMostRecent: { nil },
        getRecentRequests: { _ in [] },
        clearHistory: { }
      )

      let loggerClient = LoggerClient(
        log: { _, _, _, _, _, _ in },
        getRecentLogs: { _ in [] },
        clearLogs: { },
        exportLogs: { Data() },
        setMinLevel: { _ in }
      )

      let middleware = CorrelationMiddleware(correlationClient: correlationClient, logger: loggerClient)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "testOperation"
        ) { _, _, _ in
          (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore
      }

      #expect(completedCorrelationId == testCorrelationId)
      #expect(completedStatusCode == 200)
    }

    @Test("Calls failRequest on error")
    func callsFailRequestOnError() async throws {
      var failedCorrelationId: UUID?
      var failedErrorMessage: String?

      let testCorrelationId = UUID()
      let correlationClient = CorrelationClient(
        startRequest: { _, _ in testCorrelationId },
        completeRequest: { _, _, _, _ in },
        failRequest: { correlationId, errorMessage, _ in
          failedCorrelationId = correlationId
          failedErrorMessage = errorMessage
        },
        getMostRecent: { nil },
        getRecentRequests: { _ in [] },
        clearHistory: { }
      )

      let loggerClient = LoggerClient(
        log: { _, _, _, _, _, _ in },
        getRecentLogs: { _ in [] },
        clearLogs: { },
        exportLogs: { Data() },
        setMinLevel: { _ in }
      )

      let middleware = CorrelationMiddleware(correlationClient: correlationClient, logger: loggerClient)

      var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/test")

      struct TestError: Error, LocalizedError {
        var errorDescription: String? { "Test network failure" }
      }

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "testOperation"
        ) { _, _, _ in
          throw TestError()
        }
      } catch {
        // Expected to throw
      }

      #expect(failedCorrelationId == testCorrelationId)
      #expect(failedErrorMessage == "Test network failure")
    }

    // Helper to capture the X-Correlation-ID header from modified request
    private func captureCorrelationIdHeader(middleware: CorrelationMiddleware, request: inout HTTPRequest) async -> String? {
      var capturedHeader: String?

      do {
        _ = try await middleware.intercept(
          request,
          body: nil,
          baseURL: URL(string: "https://example.com")!,
          operationID: "test"
        ) { modifiedRequest, _, _ in
          capturedHeader = modifiedRequest.headerFields[.init("X-Correlation-ID")!]
          return (HTTPResponse(status: .ok), nil)
        }
      } catch {
        // Ignore errors for this test
      }

      return capturedHeader
    }
  }
}
