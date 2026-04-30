import ComposableArchitecture
import Foundation

public enum DownloadQuality: String, CaseIterable, Codable, Sendable {
  case auto
  case high
  case medium
  case low

  public var displayName: String {
    switch self {
    case .auto:
      "Auto (Recommended)"
    case .high:
      "High Quality"
    case .medium:
      "Medium Quality"
    case .low:
      "Low Quality (Data Saver)"
    }
  }

  public var qualityDescription: String {
    switch self {
    case .auto:
      "Automatically selects quality based on network conditions"
    case .high:
      "Best quality, larger file sizes"
    case .medium:
      "Balanced quality and file size"
    case .low:
      "Smaller files, reduced quality"
    }
  }
}

@DependencyClient
public struct UserDefaultsClient: Sendable {
  public var getDownloadQuality: @Sendable () -> DownloadQuality = { .auto }
  public var setDownloadQuality: @Sendable (DownloadQuality) -> Void
  public var getCellularDownloadsEnabled: @Sendable () -> Bool = { false }
  public var setCellularDownloadsEnabled: @Sendable (Bool) -> Void
}

public extension DependencyValues {
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
  public static let liveValue = UserDefaultsClient(
    getDownloadQuality: {
      guard let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.downloadQuality),
            let quality = DownloadQuality(rawValue: rawValue)
      else {
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
