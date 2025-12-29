import Foundation

// https://thoughtbot.com/blog/let-s-setup-your-ios-environments
public enum Environment {
  /// Check if running in a test environment
  private static var isTestEnvironment: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
    NSClassFromString("XCTestCase") != nil
  }

  /// Check if LocalStack is enabled for integration testing
  /// Set LOCALSTACK_ENABLED=true in environment to use LocalStack endpoints
  static var isLocalStackEnabled: Bool {
    ProcessInfo.processInfo.environment["LOCALSTACK_ENABLED"] == "true"
  }

  /// LocalStack API Gateway endpoint (default port 4566)
  /// Can be overridden with LOCALSTACK_API_ENDPOINT environment variable
  static var localStackAPIEndpoint: String {
    ProcessInfo.processInfo.environment["LOCALSTACK_API_ENDPOINT"]
      ?? "http://localhost:4566/restapis/test-api/local/_user_request_"
  }

  /// LocalStack API key for testing
  static var localStackAPIKey: String {
    ProcessInfo.processInfo.environment["LOCALSTACK_API_KEY"]
      ?? "test-api-key-localstack"
  }

  private static let infoDictionary: [String: Any] = {
    // In test environments, Bundle.main.infoDictionary may be nil or missing keys
    Bundle.main.infoDictionary ?? [:]
  }()

  static let basePath: String = {
    // Check for LocalStack integration testing
    if isLocalStackEnabled {
      print("🧪 Using LocalStack endpoint: \(localStackAPIEndpoint)")
      return localStackAPIEndpoint
    }

    if let basePath = Environment.infoDictionary["MEDIA_DOWNLOADER_BASE_PATH"] as? String {
      return basePath
    }
    // Fallback for test environments
    if isTestEnvironment {
      return "https://test.example.com/"
    }
    fatalError("MEDIA_DOWNLOADER_BASE_PATH not set in plist for this environment")
  }()

  static let apiKey: String = {
    // Check for LocalStack integration testing
    if isLocalStackEnabled {
      return localStackAPIKey
    }

    if let apiKey = Environment.infoDictionary["MEDIA_DOWNLOADER_API_KEY"] as? String {
      return apiKey
    }
    // Fallback for test environments
    if isTestEnvironment {
      return "test-api-key"
    }
    fatalError("MEDIA_DOWNLOADER_API_KEY not set in plist for this environment")
  }()
}
