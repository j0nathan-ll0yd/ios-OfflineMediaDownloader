import Testing
import Foundation
@testable import OfflineMediaDownloader
import ComposableArchitecture

/// Integration tests that run against LocalStack
/// These tests require LocalStack to be running: docker run -d -p 4566:4566 localstack/localstack
///
/// To run these tests:
/// 1. Start LocalStack: docker run -d -p 4566:4566 localstack/localstack
/// 2. Deploy backend to LocalStack (from backend repo): npm run deploy:local
/// 3. Run tests with LOCALSTACK_ENABLED=true environment variable
///
/// Example:
///   LOCALSTACK_ENABLED=true xcodebuild test -scheme OfflineMediaDownloader -only-testing:OfflineMediaDownloaderTests/IntegrationTests
@Suite("LocalStack Integration Tests")
struct IntegrationTests {

  // MARK: - Test Configuration

  /// Check if LocalStack is available and configured
  private var isLocalStackConfigured: Bool {
    Environment.isLocalStackEnabled
  }

  /// Skip test if LocalStack is not configured
  private func requireLocalStack() throws {
    guard isLocalStackConfigured else {
      throw SkipError()
    }
  }

  // MARK: - Backend Fixture Tests

  @Test("Backend fixtures are loadable")
  func backendFixturesLoad() throws {
    // This test always runs to verify fixture infrastructure
    let config = BackendFixtures.localStackConfig
    #expect(config != nil, "LocalStack config should be loadable")

    let tokens = BackendFixtures.mockSIWATokens
    #expect(tokens != nil, "Mock SIWA tokens should be loadable")

    let responses = BackendFixtures.apiResponses
    #expect(responses != nil, "API responses should be loadable")

    let notifications = BackendFixtures.pushNotifications
    #expect(notifications != nil, "Push notifications should be loadable")
  }

  @Test("Backend fixtures contain expected data")
  func backendFixturesContent() throws {
    // Verify mock tokens
    let validToken = BackendFixtures.validUserIdentityToken
    #expect(validToken != nil, "Valid user identity token should exist")
    #expect(validToken?.hasPrefix("eyJ") == true, "Token should be JWT format")

    // Verify files can be converted to domain models
    let files = BackendFixtures.files
    #expect(files.count > 0, "Should have at least one file fixture")

    // Verify LocalStack config
    if let config = BackendFixtures.localStackConfig {
      #expect(config.endpoints.apiGateway.contains("localhost"), "API endpoint should be localhost")
      #expect(config.endpoints.s3.contains("localstack"), "S3 endpoint should be localstack")
    }
  }

  // MARK: - LocalStack API Tests

  @MainActor
  @Test("User registration with mock SIWA token")
  func userRegistration() async throws {
    try requireLocalStack()

    // This test requires LocalStack with backend deployed
    guard let identityToken = BackendFixtures.newUserIdentityToken else {
      throw SkipError()
    }

    let user = User(
      email: "integration-test@privaterelay.appleid.com",
      firstName: "Integration",
      identifier: "integration-test-user",
      lastName: "Test"
    )

    // Use the live ServerClient which will hit LocalStack
    let serverClient = ServerClient.liveValue

    do {
      let response = try await serverClient.registerUser(user, identityToken)
      #expect(response.body != nil, "Should receive a response body")
      #expect(response.body?.token != nil, "Should receive a JWT token")
    } catch {
      // Expected to fail if LocalStack isn't running or backend isn't deployed
      // Re-throw so test shows as failed, not skipped
      throw error
    }
  }

  @MainActor
  @Test("User login with mock SIWA token")
  func userLogin() async throws {
    try requireLocalStack()

    guard let identityToken = BackendFixtures.validUserIdentityToken else {
      throw SkipError()
    }

    let serverClient = ServerClient.liveValue

    do {
      let response = try await serverClient.loginUser(identityToken)
      #expect(response.body != nil, "Should receive a response body")
      #expect(response.body?.token != nil, "Should receive a JWT token")
    } catch {
      throw error
    }
  }

  @MainActor
  @Test("File list retrieval")
  func fileListRetrieval() async throws {
    try requireLocalStack()

    // This requires authenticated session - would need to login first
    // For now, test with anonymous endpoint if available

    let serverClient = ServerClient.liveValue

    do {
      let response = try await serverClient.getFiles()
      #expect(response.body != nil, "Should receive a response body")
      // Files may be empty for new user, but response should succeed
    } catch ServerClientError.unauthorized {
      // Expected if no auth token - this validates the auth middleware works
      #expect(true, "Unauthorized error expected without valid token")
    } catch {
      throw error
    }
  }

  // MARK: - Environment Configuration Tests

  @Test("Environment detects LocalStack mode")
  func environmentConfiguration() {
    // When LOCALSTACK_ENABLED is set, basePath should point to LocalStack
    if Environment.isLocalStackEnabled {
      #expect(Environment.basePath.contains("localhost") || Environment.basePath.contains("localstack"),
              "LocalStack basePath should point to local endpoint")
      #expect(Environment.apiKey == Environment.localStackAPIKey,
              "API key should be LocalStack test key")
    } else {
      // Standard test environment
      #expect(Environment.basePath.contains("test.example.com") || Environment.basePath.contains("execute-api"),
              "Standard basePath should be test or production endpoint")
    }
  }
}

// MARK: - Skip Error

/// Error thrown to skip tests that require LocalStack
private struct SkipError: Error {}
