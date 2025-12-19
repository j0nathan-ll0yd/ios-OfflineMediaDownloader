import Foundation

// https://thoughtbot.com/blog/let-s-setup-your-ios-environments
public enum Environment {
  /// Check if running in a test environment
  private static var isTestEnvironment: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
    NSClassFromString("XCTestCase") != nil
  }

  private static let infoDictionary: [String: Any] = {
    // In test environments, Bundle.main.infoDictionary may be nil or missing keys
    Bundle.main.infoDictionary ?? [:]
  }()

  static let basePath: String = {
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
