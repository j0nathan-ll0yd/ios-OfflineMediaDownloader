import ComposableArchitecture
import Foundation
import Valet

class ValetUtil {
  static var shared: ValetUtil = ValetUtil()
  var secureEnclave: SecureEnclaveValet?
  var keychain: Valet

  // App Group identifier for sharing keychain between app and extensions
  // Team ID: P328YB6M54
  static let sharedGroupIdentifier = SharedGroupIdentifier(
    appIDPrefix: "P328YB6M54",
    nonEmptyGroup: "group.com.jlloyd.OfflineMediaDownloader"
  )!

  // Legacy identifier for migration purposes (kept for reference)
  static let legacyIdentifier: String = {
    if let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty {
      return "\(bundleId).Valet"
    }
    return "com.test.OfflineMediaDownloader.Valet"
  }()

  private init() {
    // SecureEnclaveValet is not available in simulator environments
    // and may fail on devices without Secure Enclave hardware
    #if targetEnvironment(simulator)
    secureEnclave = nil
    #else
    // Try to create SecureEnclaveValet with shared group for extension access
    secureEnclave = SecureEnclaveValet.sharedGroupValet(
      with: ValetUtil.sharedGroupIdentifier,
      accessControl: .userPresence
    )
    #endif

    // Use shared group valet so Share Extension can access the keychain
    keychain = Valet.sharedGroupValet(
      with: ValetUtil.sharedGroupIdentifier,
      accessibility: .whenUnlocked
    )
  }
}

// This enum maintains ALL keys stored in the Keychain. They MUST be unique.
enum KeychainKeys: String {
  case email
  case firstName
  case identifier
  case lastName
  case jwtToken
  case endpointArn
}

@DependencyClient
struct KeychainClient {
  var getUserData: @Sendable () async throws -> User
  var getJwtToken: @Sendable () async throws -> String?
  var getDeviceData: @Sendable () async throws -> Device?
  var getUserIdentifier: @Sendable () async throws -> String?
  var setUserData: @Sendable (_ userData: User) async throws -> Void
  var setJwtToken: @Sendable (_ token: String) async throws -> Void
  var setDeviceData: @Sendable (_ deviceData: Device) async throws -> Void
  var deleteUserData: @Sendable () async throws -> Void
  var deleteJwtToken: @Sendable () async throws -> Void
  var deleteDeviceData: @Sendable () async throws -> Void
}

extension DependencyValues {
  var keychainClient: KeychainClient {
    get { self[KeychainClient.self] }
    set { self[KeychainClient.self] = newValue }
  }
}

enum KeychainError: Error {
  case unableToStore
  case itemNotFound
}

/// Checks if an error represents "item not found" in the keychain.
/// Valet throws its own KeychainError.itemNotFound, which we need to detect.
private func isItemNotFoundError(_ error: Error) -> Bool {
  // Check the string description since Valet's KeychainError is internal
  let errorDescription = String(describing: error)
  return errorDescription.contains("itemNotFound")
}

// MARK: - Live API implementation
extension KeychainClient: DependencyKey {
  static let liveValue = KeychainClient(
    getUserData: {
      let userData = User(
        email: try ValetUtil.shared.keychain.string(forKey: KeychainKeys.email.rawValue),
        firstName: try ValetUtil.shared.keychain.string(forKey: KeychainKeys.firstName.rawValue),
        identifier: try ValetUtil.shared.keychain.string(forKey: KeychainKeys.identifier.rawValue),
        lastName: try ValetUtil.shared.keychain.string(forKey: KeychainKeys.lastName.rawValue)
      )
      return userData
    },
    getJwtToken: {
      do {
        return try ValetUtil.shared.keychain.string(forKey: KeychainKeys.jwtToken.rawValue)
      } catch {
        // itemNotFound is expected when token doesn't exist - only log unexpected errors
        if !isItemNotFoundError(error) {
          print("⚠️ KeychainClient.getJwtToken unexpected error: \(error)")
        }
        return nil
      }
    },
    getDeviceData: {
      do {
        let endpointArn = try ValetUtil.shared.keychain.string(forKey: KeychainKeys.endpointArn.rawValue)
        return Device(endpointArn: endpointArn)
      } catch {
        // itemNotFound is expected when device data doesn't exist
        if !isItemNotFoundError(error) {
          print("⚠️ KeychainClient.getDeviceData unexpected error: \(error)")
        }
        return nil
      }
    },
    getUserIdentifier: {
      do {
        return try ValetUtil.shared.keychain.string(forKey: KeychainKeys.identifier.rawValue)
      } catch {
        // itemNotFound is expected when user hasn't registered
        if !isItemNotFoundError(error) {
          print("⚠️ KeychainClient.getUserIdentifier unexpected error: \(error)")
        }
        return nil
      }
    },
    setUserData: { userData in
      do {
        try ValetUtil.shared.keychain.setString(userData.email, forKey: KeychainKeys.email.rawValue)
        try ValetUtil.shared.keychain.setString(userData.firstName, forKey: KeychainKeys.firstName.rawValue)
        try ValetUtil.shared.keychain.setString(userData.identifier, forKey: KeychainKeys.identifier.rawValue)
        try ValetUtil.shared.keychain.setString(userData.lastName, forKey: KeychainKeys.lastName.rawValue)
      } catch {
        throw KeychainError.unableToStore
      }
    },
    setJwtToken: { token in
      debugPrint("KeychainClient.setJwtToken called with token length: \(token.count)")
      do {
        try ValetUtil.shared.keychain.setString(token, forKey: KeychainKeys.jwtToken.rawValue)
        debugPrint("KeychainClient.setJwtToken succeeded")
      } catch {
        debugPrint("KeychainClient.setJwtToken failed: \(error)")
        throw error
      }
    },
    setDeviceData: { deviceData in
      try ValetUtil.shared.keychain.setString(deviceData.endpointArn, forKey: KeychainKeys.endpointArn.rawValue)
    },
    deleteUserData: {
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.email.rawValue)
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.firstName.rawValue)
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.identifier.rawValue)
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.lastName.rawValue)
    },
    deleteJwtToken: {
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.jwtToken.rawValue)
    },
    deleteDeviceData: {
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.endpointArn.rawValue)
    }
  )
}
