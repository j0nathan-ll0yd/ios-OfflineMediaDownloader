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
    determineLoginStatus: { .unauthenticated }
  )
}
