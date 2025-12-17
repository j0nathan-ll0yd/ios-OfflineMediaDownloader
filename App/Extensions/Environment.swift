import Foundation

// https://thoughtbot.com/blog/let-s-setup-your-ios-environments
public enum Environment {
  private static let infoDictionary: [String: Any] = {
    guard let dict = Bundle.main.infoDictionary else {
      fatalError("Plist file not found")
    }
    return dict
  }()
    
  static let basePath: String = {
    guard let basePath = Environment.infoDictionary["MEDIA_DOWNLOADER_BASE_PATH"] as? String else {
      fatalError("MEDIA_DOWNLOADER_BASE_PATH not set in plist for this environment")
    }
    return basePath
  }()

  static let apiKey: String = {
    guard let apiKey = Environment.infoDictionary["MEDIA_DOWNLOADER_API_KEY"] as? String else {
      fatalError("MEDIA_DOWNLOADER_API_KEY not set in plist for this environment")
    }
    return apiKey
  }()
}
