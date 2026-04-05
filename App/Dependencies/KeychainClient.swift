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
    guard let identifier = Identifier(nonEmpty: ValetUtil.identifier) else {
      fatalError("ValetUtil.identifier is guaranteed non-empty by its computed fallback")
    }

    // SecureEnclaveValet is not available in simulator environments
    // and may fail on devices without Secure Enclave hardware
    #if targetEnvironment(simulator)
    secureEnclave = nil
    #else
    // Try to create SecureEnclaveValet, but it may fail on older devices
    // or in certain CI environments
    secureEnclave = SecureEnclaveValet.valet(
      with: identifier,
      accessControl: .userPresence
    )
    #endif

    keychain = Valet.valet(
      with: identifier,
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
  case jwtTokenExpiresAt
  case endpointArn
}

@DependencyClient
struct KeychainClient {
  var getUserData: @Sendable () async throws -> User
  var getJwtToken: @Sendable () async throws -> String?
  var getTokenExpiresAt: @Sendable () async throws -> Date?
  var getDeviceData: @Sendable () async throws -> Device?
  var getUserIdentifier: @Sendable () async throws -> String?
  var setUserData: @Sendable (_ userData: User) async throws -> Void
  var setJwtToken: @Sendable (_ token: String) async throws -> Void
  var setTokenExpiresAt: @Sendable (_ expiresAt: Date) async throws -> Void
  var setDeviceData: @Sendable (_ deviceData: Device) async throws -> Void
  var deleteUserData: @Sendable () async throws -> Void
  var deleteJwtToken: @Sendable () async throws -> Void
  var deleteTokenExpiresAt: @Sendable () async throws -> Void
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
        // JWT tokens use regular keychain with .whenUnlocked accessibility
        // SecureEnclaveValet requires biometric prompt per-access which isn't appropriate for frequent token checks
        let token = try ValetUtil.shared.keychain.string(forKey: KeychainKeys.jwtToken.rawValue)
        let preview = String(token.prefix(20)) + "..."
        print("🔑 KeychainClient.getJwtToken: found token (\(preview))")
        return token
      } catch {
        // itemNotFound is expected when token doesn't exist - only log unexpected errors
        if isItemNotFoundError(error) {
          print("🔑 KeychainClient.getJwtToken: no token found (itemNotFound)")
        } else {
          print("⚠️ KeychainClient.getJwtToken unexpected error: \(error)")
        }
        return nil
      }
    },
    getTokenExpiresAt: {
      do {
        let timestamp = try ValetUtil.shared.keychain.string(forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
        guard let timeInterval = Double(timestamp) else {
          print("⚠️ KeychainClient.getTokenExpiresAt: invalid timestamp format")
          return nil
        }
        let date = Date(timeIntervalSince1970: timeInterval)
        print("🔑 KeychainClient.getTokenExpiresAt: found expiration \(date)")
        return date
      } catch {
        if isItemNotFoundError(error) {
          print("🔑 KeychainClient.getTokenExpiresAt: no expiration found (itemNotFound)")
        } else {
          print("⚠️ KeychainClient.getTokenExpiresAt unexpected error: \(error)")
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
      let preview = String(token.prefix(20)) + "..."
      print("🔑 KeychainClient.setJwtToken: storing token (\(token.count) chars, \(preview))")
      do {
        // JWT tokens use regular keychain with .whenUnlocked accessibility
        try ValetUtil.shared.keychain.setString(token, forKey: KeychainKeys.jwtToken.rawValue)
        print("🔑 KeychainClient.setJwtToken: succeeded")
      } catch {
        print("⚠️ KeychainClient.setJwtToken: failed with error: \(error)")
        throw error
      }
    },
    setTokenExpiresAt: { expiresAt in
      let timestamp = String(expiresAt.timeIntervalSince1970)
      print("🔑 KeychainClient.setTokenExpiresAt: storing expiration \(expiresAt)")
      try ValetUtil.shared.keychain.setString(timestamp, forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
      print("🔑 KeychainClient.setTokenExpiresAt: succeeded")
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
      print("🔑 KeychainClient.deleteJwtToken: removing token from keychain")
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.jwtToken.rawValue)
      print("🔑 KeychainClient.deleteJwtToken: token removed")
    },
    deleteTokenExpiresAt: {
      print("🔑 KeychainClient.deleteTokenExpiresAt: removing expiration from keychain")
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
      print("🔑 KeychainClient.deleteTokenExpiresAt: expiration removed")
    },
    deleteDeviceData: {
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.endpointArn.rawValue)
    }
  )

  static let testValue = KeychainClient(
    getUserData: { User(email: "test@example.com", firstName: "Test", identifier: "test-id", lastName: "User") },
    getJwtToken: { "test-jwt-token" },
    getTokenExpiresAt: { Date().addingTimeInterval(3600) },
    getDeviceData: { Device(endpointArn: "test-endpoint-arn") },
    getUserIdentifier: { "test-user-id" },
    setUserData: { _ in },
    setJwtToken: { _ in },
    setTokenExpiresAt: { _ in },
    setDeviceData: { _ in },
    deleteUserData: { },
    deleteJwtToken: { },
    deleteTokenExpiresAt: { },
    deleteDeviceData: { }
  )
}
