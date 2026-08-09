import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import LoggerClient
import SharedModels
import Valet

public final class ValetUtil: Sendable {
  public static let shared = ValetUtil()
  public let secureEnclave: SecureEnclaveValet?
  public let keychain: Valet
  public let sharedKeychain: Valet?

  /// Use a safe identifier that works in both app and test environments
  public static let identifier: String = {
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

    if let groupId = SharedGroupIdentifier(groupPrefix: "group", nonEmptyGroup: "lifegames.OfflineMediaDownloader") {
      sharedKeychain = Valet.sharedGroupValet(with: groupId, accessibility: .afterFirstUnlock)
    } else {
      sharedKeychain = nil
    }
  }
}

/// This enum maintains ALL keys stored in the Keychain. They MUST be unique.
public enum KeychainKeys: String {
  case email
  case firstName
  case identifier
  case lastName
  case jwtToken
  case jwtTokenExpiresAt
  case endpointArn
}

@DependencyClient
public struct KeychainClient: Sendable {
  public var getUserData: @Sendable () async throws -> User
  public var getJwtToken: @Sendable () async throws -> String?
  public var getTokenExpiresAt: @Sendable () async throws -> Date?
  public var getDeviceData: @Sendable () async throws -> Device?
  public var getUserIdentifier: @Sendable () async throws -> String?
  public var setUserData: @Sendable (_ userData: User) async throws -> Void
  public var setJwtToken: @Sendable (_ token: String) async throws -> Void
  public var setTokenExpiresAt: @Sendable (_ expiresAt: Date) async throws -> Void
  public var setDeviceData: @Sendable (_ deviceData: Device) async throws -> Void
  public var setUserIdentifier: @Sendable (_ identifier: String) async throws -> Void
  public var deleteUserData: @Sendable () async throws -> Void
  public var deleteJwtToken: @Sendable () async throws -> Void
  public var deleteTokenExpiresAt: @Sendable () async throws -> Void
  public var deleteDeviceData: @Sendable () async throws -> Void
}

public extension DependencyValues {
  var keychainClient: KeychainClient {
    get { self[KeychainClient.self] }
    set { self[KeychainClient.self] = newValue }
  }
}

public enum KeychainError: Error {
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
  public static let liveValue = KeychainClient(
    getUserData: {
      try User(
        email: ValetUtil.shared.keychain.string(forKey: KeychainKeys.email.rawValue),
        firstName: ValetUtil.shared.keychain.string(forKey: KeychainKeys.firstName.rawValue),
        identifier: ValetUtil.shared.keychain.string(forKey: KeychainKeys.identifier.rawValue),
        lastName: ValetUtil.shared.keychain.string(forKey: KeychainKeys.lastName.rawValue)
      )
    },
    getJwtToken: {
      @Dependency(\.logger) var logger
      do {
        let token = try ValetUtil.shared.keychain.string(forKey: KeychainKeys.jwtToken.rawValue)
        let preview = String(token.prefix(20)) + "..."
        logger.debug(.auth, "KeychainClient.getJwtToken: found token (\(preview))")
        return token
      } catch {
        if isItemNotFoundError(error) {
          logger.debug(.auth, "KeychainClient.getJwtToken: no token found (itemNotFound)")
        } else {
          logger.warning(.auth, "KeychainClient.getJwtToken unexpected error: \(error)")
        }
        return nil
      }
    },
    getTokenExpiresAt: {
      @Dependency(\.logger) var logger
      do {
        let timestamp = try ValetUtil.shared.keychain.string(forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
        guard let timeInterval = Double(timestamp) else {
          logger.warning(.auth, "KeychainClient.getTokenExpiresAt: invalid timestamp format")
          return nil
        }
        let date = Date(timeIntervalSince1970: timeInterval)
        logger.debug(.auth, "KeychainClient.getTokenExpiresAt: found expiration \(date)")
        return date
      } catch {
        if isItemNotFoundError(error) {
          logger.debug(.auth, "KeychainClient.getTokenExpiresAt: no expiration found (itemNotFound)")
        } else {
          logger.warning(.auth, "KeychainClient.getTokenExpiresAt unexpected error: \(error)")
        }
        return nil
      }
    },
    getDeviceData: {
      @Dependency(\.logger) var logger
      do {
        let endpointArn = try ValetUtil.shared.keychain.string(forKey: KeychainKeys.endpointArn.rawValue)
        return Device(endpointArn: endpointArn)
      } catch {
        if !isItemNotFoundError(error) {
          logger.warning(.auth, "KeychainClient.getDeviceData unexpected error: \(error)")
        }
        return nil
      }
    },
    getUserIdentifier: {
      @Dependency(\.logger) var logger
      do {
        return try ValetUtil.shared.keychain.string(forKey: KeychainKeys.identifier.rawValue)
      } catch {
        if !isItemNotFoundError(error) {
          logger.warning(.auth, "KeychainClient.getUserIdentifier unexpected error: \(error)")
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
      @Dependency(\.logger) var logger
      let preview = String(token.prefix(20)) + "..."
      logger.debug(.auth, "KeychainClient.setJwtToken: storing token (\(token.count) chars, \(preview))")
      do {
        try ValetUtil.shared.keychain.setString(token, forKey: KeychainKeys.jwtToken.rawValue)
        try? ValetUtil.shared.sharedKeychain?.setString(token, forKey: KeychainKeys.jwtToken.rawValue)
        logger.debug(.auth, "KeychainClient.setJwtToken: succeeded")
      } catch {
        logger.warning(.auth, "KeychainClient.setJwtToken: failed with error: \(error)")
        throw error
      }
    },
    setTokenExpiresAt: { expiresAt in
      @Dependency(\.logger) var logger
      let timestamp = String(expiresAt.timeIntervalSince1970)
      logger.debug(.auth, "KeychainClient.setTokenExpiresAt: storing expiration \(expiresAt)")
      try ValetUtil.shared.keychain.setString(timestamp, forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
      try? ValetUtil.shared.sharedKeychain?.setString(timestamp, forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
      logger.debug(.auth, "KeychainClient.setTokenExpiresAt: succeeded")
    },
    setDeviceData: { deviceData in
      try ValetUtil.shared.keychain.setString(deviceData.endpointArn, forKey: KeychainKeys.endpointArn.rawValue)
    },
    setUserIdentifier: { identifier in
      @Dependency(\.logger) var logger
      logger.debug(.auth, "KeychainClient.setUserIdentifier: storing identifier")
      do {
        try ValetUtil.shared.keychain.setString(identifier, forKey: KeychainKeys.identifier.rawValue)
        logger.debug(.auth, "KeychainClient.setUserIdentifier: succeeded")
      } catch {
        logger.warning(.auth, "KeychainClient.setUserIdentifier: failed with error: \(error)")
        throw error
      }
    },
    deleteUserData: {
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.email.rawValue)
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.firstName.rawValue)
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.identifier.rawValue)
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.lastName.rawValue)
    },
    deleteJwtToken: {
      @Dependency(\.logger) var logger
      logger.debug(.auth, "KeychainClient.deleteJwtToken: removing token from keychain")
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.jwtToken.rawValue)
      try? ValetUtil.shared.sharedKeychain?.removeObject(forKey: KeychainKeys.jwtToken.rawValue)
      logger.debug(.auth, "KeychainClient.deleteJwtToken: token removed")
    },
    deleteTokenExpiresAt: {
      @Dependency(\.logger) var logger
      logger.debug(.auth, "KeychainClient.deleteTokenExpiresAt: removing expiration from keychain")
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
      try? ValetUtil.shared.sharedKeychain?.removeObject(forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
      logger.debug(.auth, "KeychainClient.deleteTokenExpiresAt: expiration removed")
    },
    deleteDeviceData: {
      try ValetUtil.shared.keychain.removeObject(forKey: KeychainKeys.endpointArn.rawValue)
    }
  )

  public static var testValue: KeychainClient {
    .inMemory()
  }

  public static var previewValue: KeychainClient {
    .inMemory()
  }
}

// MARK: - In-Memory Implementation

public extension KeychainClient {
  static func inMemory(initialValues: [String: String] = [:]) -> KeychainClient {
    let storage = LockIsolated(initialValues)
    return KeychainClient(
      getUserData: {
        guard let email = storage.withValue({ $0[KeychainKeys.email.rawValue] }),
              let firstName = storage.withValue({ $0[KeychainKeys.firstName.rawValue] }),
              let identifier = storage.withValue({ $0[KeychainKeys.identifier.rawValue] }),
              let lastName = storage.withValue({ $0[KeychainKeys.lastName.rawValue] })
        else {
          throw KeychainError.itemNotFound
        }
        return User(
          email: email,
          firstName: firstName,
          identifier: identifier,
          lastName: lastName
        )
      },
      getJwtToken: {
        storage.withValue { $0[KeychainKeys.jwtToken.rawValue] }
      },
      getTokenExpiresAt: {
        guard let timestamp = storage.withValue({ $0[KeychainKeys.jwtTokenExpiresAt.rawValue] }),
              let timeInterval = Double(timestamp)
        else {
          return nil
        }
        return Date(timeIntervalSince1970: timeInterval)
      },
      getDeviceData: {
        guard let endpointArn = storage.withValue({ $0[KeychainKeys.endpointArn.rawValue] }) else {
          return nil
        }
        return Device(endpointArn: endpointArn)
      },
      getUserIdentifier: {
        storage.withValue { $0[KeychainKeys.identifier.rawValue] }
      },
      setUserData: { userData in
        storage.withValue { (dict: inout [String: String]) in
          dict[KeychainKeys.email.rawValue] = userData.email
          dict[KeychainKeys.firstName.rawValue] = userData.firstName
          dict[KeychainKeys.identifier.rawValue] = userData.identifier
          dict[KeychainKeys.lastName.rawValue] = userData.lastName
        }
      },
      setJwtToken: { token in
        storage.withValue { (dict: inout [String: String]) in
          dict[KeychainKeys.jwtToken.rawValue] = token
        }
      },
      setTokenExpiresAt: { expiresAt in
        let timestamp = String(expiresAt.timeIntervalSince1970)
        storage.withValue { (dict: inout [String: String]) in
          dict[KeychainKeys.jwtTokenExpiresAt.rawValue] = timestamp
        }
      },
      setDeviceData: { deviceData in
        storage.withValue { (dict: inout [String: String]) in
          dict[KeychainKeys.endpointArn.rawValue] = deviceData.endpointArn
        }
      },
      setUserIdentifier: { identifier in
        storage.withValue { (dict: inout [String: String]) in
          dict[KeychainKeys.identifier.rawValue] = identifier
        }
      },
      deleteUserData: {
        storage.withValue { (dict: inout [String: String]) in
          dict.removeValue(forKey: KeychainKeys.email.rawValue)
          dict.removeValue(forKey: KeychainKeys.firstName.rawValue)
          dict.removeValue(forKey: KeychainKeys.identifier.rawValue)
          dict.removeValue(forKey: KeychainKeys.lastName.rawValue)
        }
      },
      deleteJwtToken: {
        storage.withValue { (dict: inout [String: String]) in
          dict.removeValue(forKey: KeychainKeys.jwtToken.rawValue)
        }
      },
      deleteTokenExpiresAt: {
        storage.withValue { (dict: inout [String: String]) in
          dict.removeValue(forKey: KeychainKeys.jwtTokenExpiresAt.rawValue)
        }
      },
      deleteDeviceData: {
        storage.withValue { (dict: inout [String: String]) in
          dict.removeValue(forKey: KeychainKeys.endpointArn.rawValue)
        }
      }
    )
  }
}
