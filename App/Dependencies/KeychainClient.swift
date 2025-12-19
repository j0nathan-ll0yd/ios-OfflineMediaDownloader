import ComposableArchitecture
import Foundation
import Valet

class ValetUtil {
  static var shared: ValetUtil = ValetUtil()
  var secureEnclave: SecureEnclaveValet?
  var keychain: Valet

  // Use a safe identifier that works in both app and test environments
  static let identifier: String = {
    if let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty {
      return "\(bundleId).Valet"
    }
    // Fallback for test environments where bundleIdentifier may not be available
    return "com.test.OfflineMediaDownloader.Valet"
  }()

  private init() {
    // SecureEnclaveValet is not available in simulator environments
    // and may fail on devices without Secure Enclave hardware
    #if targetEnvironment(simulator)
    secureEnclave = nil
    #else
    // Try to create SecureEnclaveValet, but it may fail on older devices
    // or in certain CI environments
    secureEnclave = SecureEnclaveValet.valet(
      with: Identifier(nonEmpty: ValetUtil.identifier)!,
      accessControl: .userPresence
    )
    #endif

    keychain = Valet.valet(
      with: Identifier(nonEmpty: ValetUtil.identifier)!,
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
        // errSecItemNotFound (-25300) is expected when token doesn't exist
        let nsError = error as NSError
        if nsError.code != -25300 {
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
        let nsError = error as NSError
        if nsError.code != -25300 {
          print("⚠️ KeychainClient.getDeviceData unexpected error: \(error)")
        }
        return nil
      }
    },
    getUserIdentifier: {
      do {
        return try ValetUtil.shared.keychain.string(forKey: KeychainKeys.identifier.rawValue)
      } catch {
        let nsError = error as NSError
        if nsError.code != -25300 {
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
