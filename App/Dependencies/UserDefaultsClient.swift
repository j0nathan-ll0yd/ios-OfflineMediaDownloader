import ComposableArchitecture
import Foundation

/// Download quality preferences
enum DownloadQuality: String, CaseIterable, Sendable, Codable {
  case auto = "auto"
  case high = "high"
  case medium = "medium"
  case low = "low"

  var displayName: String {
    switch self {
    case .auto:
      return "Auto (Recommended)"
    case .high:
      return "High Quality"
    case .medium:
      return "Medium Quality"
    case .low:
      return "Low Quality (Data Saver)"
    }
  }

  var description: String {
    switch self {
    case .auto:
      return "Automatically selects quality based on network conditions"
    case .high:
      return "Best quality, larger file sizes"
    case .medium:
      return "Balanced quality and file size"
    case .low:
      return "Smaller files, reduced quality"
    }
  }
}

/// Client for accessing user preferences stored in UserDefaults
@DependencyClient
struct UserDefaultsClient {
  var getDownloadQuality: @Sendable () -> DownloadQuality = { .auto }
  var setDownloadQuality: @Sendable (DownloadQuality) -> Void
  var getCellularDownloadsEnabled: @Sendable () -> Bool = { false }
  var setCellularDownloadsEnabled: @Sendable (Bool) -> Void
}

extension DependencyValues {
  var userDefaultsClient: UserDefaultsClient {
    get { self[UserDefaultsClient.self] }
    set { self[UserDefaultsClient.self] = newValue }
  }
}

// MARK: - Keys
private enum UserDefaultsKeys {
  static let downloadQuality = "downloadQuality"
  static let cellularDownloadsEnabled = "cellularDownloadsEnabled"
}

// MARK: - Live Implementation
extension UserDefaultsClient: DependencyKey {
  static let liveValue = UserDefaultsClient(
    getDownloadQuality: {
      guard let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.downloadQuality),
            let quality = DownloadQuality(rawValue: rawValue) else {
        return .auto
      }
      return quality
    },
    setDownloadQuality: { quality in
      UserDefaults.standard.set(quality.rawValue, forKey: UserDefaultsKeys.downloadQuality)
    },
    getCellularDownloadsEnabled: {
      UserDefaults.standard.bool(forKey: UserDefaultsKeys.cellularDownloadsEnabled)
    },
    setCellularDownloadsEnabled: { enabled in
      UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.cellularDownloadsEnabled)
    }
  )
}

// MARK: - Test Implementation
extension UserDefaultsClient {
  static let testValue = UserDefaultsClient(
    getDownloadQuality: { .auto },
    setDownloadQuality: { _ in },
    getCellularDownloadsEnabled: { false },
    setCellularDownloadsEnabled: { _ in }
  )
}
