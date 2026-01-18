import UIKit
import SwiftUI
import AuthenticationServices
import ComposableArchitecture
import Valet

// MARK: - Models

enum LoginFeatureError: Error {
  case invalidAuthorizationCredential
}

private func handleLoginSuccess(authorization: ASAuthorization) throws -> (idToken: String, userData: User?) {
  debugPrint(authorization)
  guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
    throw LoginFeatureError.invalidAuthorizationCredential
  }
  debugPrint(credential)

  // Extract ID token (JWT) instead of authorization code
  // This reduces latency by 200-500ms by eliminating server-side token exchange
  guard let identityTokenData = credential.identityToken,
        let idToken = String(data: identityTokenData, encoding: .utf8) else {
    throw LoginFeatureError.invalidAuthorizationCredential
  }

  // New user detection: fullName is only populated on first sign-in
  // Apple's privacy model returns nil for fullName on subsequent sign-ins
  let hasFullName = credential.fullName?.givenName != nil || credential.fullName?.familyName != nil
  if hasFullName, let email = credential.email {
    let userData = User(
      email: email,
      firstName: credential.fullName?.givenName ?? "",
      identifier: credential.user,
      lastName: credential.fullName?.familyName ?? ""
    )
    return (idToken, userData)
  }
  else {
    return (idToken, nil)
  }
}

// MARK: - LoginFeature

@Reducer
struct LoginFeature {
  @ObservableState
  struct State: Equatable {
    var registrationStatus: RegistrationStatus = .unregistered
    var loginStatus: LoginStatus = .unauthenticated
    var isSigningIn: Bool = false
    var isCompletingRegistration: Bool = false
    @Presents var alert: AlertState<Action.Alert>?
    var pendingUserData: User?
  }

  enum Action {
    case loginButtonTapped
    case loginResponse(Result<LoginResponse, Error>)
    case registrationResponse(Result<LoginResponse, Error>)
    case signInWithAppleButtonTapped(Result<ASAuthorization, Error>)
    case showError(AppError)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    @CasePathable
    enum Alert: Equatable {
      case dismiss
    }

    @CasePathable
    enum Delegate: Equatable {
      case loginCompleted
      case registrationCompleted
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.keychainClient) var keychainClient

  private enum CancelID { case signIn }

  func dispatchAuthCode(send: Send<Action>, result: ASAuthorization) async throws -> Void {
    let data = try handleLoginSuccess(authorization: result)
    if let userData = data.userData {
      await send(.registrationResponse(Result {
        try await self.serverClient.registerUser(userData, data.idToken)
      }))
    } else {
      await send(.loginResponse(Result {
        try await self.serverClient.loginUser(data.idToken)
      }))
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .loginButtonTapped:
        state.alert = nil
        state.isSigningIn = true
        return .none

      case let .loginResponse(.success(response)):
        debugPrint("LoginFeature: loginResponse success, body: \(String(describing: response.body))")
        state.isSigningIn = false
        guard let token = response.body?.token else {
          return .send(.showError(.loginFailed(reason: "Invalid response: missing token")))
        }
        let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
        print("🔑 LoginFeature: token received (\(token.count) chars): \(tokenPreview)")
        state.loginStatus = .authenticated
        return .run { send in
          debugPrint("LoginFeature: storing token in keychain")
          try await keychainClient.setJwtToken(token)

          // Verify token was actually stored
          let storedToken = try await keychainClient.getJwtToken()
          guard storedToken == token else {
            debugPrint("⚠️ LoginFeature: token verification failed - stored token doesn't match")
            await send(.showError(.loginFailed(reason: "Failed to store authentication token")))
            return
          }
          debugPrint("LoginFeature: token stored and verified ✓")
          await send(.delegate(.loginCompleted))
        }

      case let .registrationResponse(.success(response)):
        debugPrint("LoginFeature: registrationResponse success, body: \(String(describing: response.body))")
        state.isSigningIn = false
        state.isCompletingRegistration = true  // Keep loading visible during token storage
        guard let token = response.body?.token else {
          state.isCompletingRegistration = false
          return .send(.showError(.registrationFailed(reason: "Invalid response: missing token")))
        }
        let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
        print("🔑 LoginFeature: token received (\(token.count) chars): \(tokenPreview)")
        state.registrationStatus = .registered
        state.loginStatus = .authenticated
        let userData = state.pendingUserData
        return .run { send in
          debugPrint("LoginFeature: storing token in keychain")
          try await keychainClient.setJwtToken(token)

          // Verify token was actually stored
          let storedToken = try await keychainClient.getJwtToken()
          guard storedToken == token else {
            debugPrint("⚠️ LoginFeature: token verification failed - stored token doesn't match")
            await send(.showError(.registrationFailed(reason: "Failed to store authentication token")))
            return
          }
          debugPrint("LoginFeature: token stored and verified ✓")

          if let userData = userData {
            try await keychainClient.setUserData(userData)
            debugPrint("LoginFeature: userData stored")
          }
          await send(.delegate(.registrationCompleted))
        }

      case let .loginResponse(.failure(error)):
        state.isSigningIn = false
        return .send(.showError(AppError.from(error)))

      case let .registrationResponse(.failure(error)):
        state.isSigningIn = false
        return .send(.showError(AppError.from(error)))

      case let .signInWithAppleButtonTapped(.success(result)):
        // Store pending user data for registration
        if let data = try? handleLoginSuccess(authorization: result) {
          state.pendingUserData = data.userData
        }
        return .run { send in
          try await dispatchAuthCode(send: send, result: result)
        }.cancellable(id: CancelID.signIn, cancelInFlight: true)

      case let .signInWithAppleButtonTapped(.failure(error)):
        state.isSigningIn = false
        return .send(.showError(AppError.from(error)))

      case let .showError(appError):
        state.alert = AlertState {
          TextState(appError.title)
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(appError.message)
        }
        return .none

      case .alert:
        return .none

      case .delegate:
        // Delegate actions are handled by parent
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
