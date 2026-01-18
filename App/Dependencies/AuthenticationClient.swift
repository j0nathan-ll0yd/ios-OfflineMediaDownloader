//
//  AuthenticationClient.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 9/4/25.
//

import ComposableArchitecture
import Foundation
import AuthenticationServices


@DependencyClient
struct AuthenticationClient {
  /// Determines the complete authentication state including both login and registration status.
  /// This is the preferred method for checking auth state on app launch.
  var determineAuthState: @Sendable () async -> AuthState = {
    AuthState(loginStatus: .unauthenticated, registrationStatus: .unregistered)
  }

  /// Determines only the login status. Prefer `determineAuthState` for launch flows.
  var determineLoginStatus: @Sendable () async throws -> LoginStatus
}

extension DependencyValues {
  var authenticationClient: AuthenticationClient {
    get { self[AuthenticationClient.self] }
    set { self[AuthenticationClient.self] = newValue }
  }
}

enum AuthenticationError: Error {
  case invalidCredentialState
}

// MARK: - Live API implementation
extension AuthenticationClient: DependencyKey {
  static let liveValue = AuthenticationClient(
    determineAuthState: {
      @Dependency(\.keychainClient) var keychainClient
      @Dependency(\.logger) var logger

      // Check for user identifier in keychain to determine registration status
      let userIdentifier: String?
      do {
        userIdentifier = try await keychainClient.getUserIdentifier()
      } catch {
        logger.warning(.auth, "Error reading user identifier from keychain", metadata: ["error": "\(error)"])
        userIdentifier = nil
      }

      // No identifier means user has never registered
      guard let currentUserIdentifier = userIdentifier else {
        logger.info(.auth, "No user identifier found - user is unregistered")
        return AuthState(loginStatus: .unauthenticated, registrationStatus: .unregistered)
      }

      // User has registered before - check if their Apple ID credentials are still valid
      let registrationStatus = RegistrationStatus.registered
      let appleIDProvider = ASAuthorizationAppleIDProvider()

      let result = await Result {
        try await appleIDProvider.credentialState(forUserID: currentUserIdentifier)
      }

      let loginStatus: LoginStatus
      switch result {
      case .success(let credentialState):
        switch credentialState {
        case .authorized:
          // Apple credentials are valid, but also verify JWT token exists
          let hasJwtToken: Bool
          do {
            hasJwtToken = try await keychainClient.getJwtToken() != nil
          } catch {
            logger.warning(.auth, "Error checking JWT token", metadata: ["error": "\(error)"])
            hasJwtToken = false
          }

          if hasJwtToken {
            loginStatus = .authenticated
            logger.info(.auth, "Apple ID credentials authorized and JWT token present")
          } else {
            loginStatus = .unauthenticated
            logger.info(.auth, "Apple ID credentials authorized but JWT token missing - user signed out")
          }
        case .revoked:
          loginStatus = .unauthenticated
          logger.info(.auth, "Apple ID credentials revoked")
        case .notFound:
          loginStatus = .unauthenticated
          logger.info(.auth, "Apple ID credentials not found")
        case .transferred:
          loginStatus = .unauthenticated
          logger.info(.auth, "Apple ID credentials transferred")
        @unknown default:
          loginStatus = .unauthenticated
          logger.warning(.auth, "Unknown Apple ID credential state")
        }
      case .failure(let error):
        logger.error(.auth, "Error checking Apple ID credential state", metadata: ["error": "\(error)"])
        loginStatus = .unauthenticated
      }

      return AuthState(loginStatus: loginStatus, registrationStatus: registrationStatus)
    },
    determineLoginStatus: {
      @Dependency(\.keychainClient) var keychainClient

      // Get the user identifier from keychain
      guard let currentUserIdentifier = try await keychainClient.getUserIdentifier() else {
        // No user data stored - user is not authenticated
        return .unauthenticated
      }

      let appleIDProvider = ASAuthorizationAppleIDProvider()

      let result = await Result {
        try await appleIDProvider.credentialState(forUserID: currentUserIdentifier)
      }
      switch result {
        case .success(let credentialState):
          switch credentialState {
            case .authorized:   return .authenticated
            case .revoked, .notFound: return .unauthenticated
            case .transferred: return .unauthenticated
            @unknown default: return .unauthenticated
          }
        case .failure(let error):
          print("Error checking credential state: \(error)")
          return .unauthenticated
      }
    }
  )
}

// MARK: - Test/Preview implementation
extension AuthenticationClient {
  static let testValue = AuthenticationClient(
    determineAuthState: { AuthState(loginStatus: .unauthenticated, registrationStatus: .unregistered) },
    determineLoginStatus: { .unauthenticated }
  )
}
