import UIKit
import SwiftUI
import AuthenticationServices
import ComposableArchitecture
import SharedModels
import ServerClient
import KeychainClient
import LoggerClient
import APIClient

// MARK: - Models

public enum LoginFeatureError: Error {
  case invalidAuthorizationCredential
}

private func handleLoginSuccess(authorization: ASAuthorization) throws -> (idToken: String, userData: User?) {
  guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
    throw LoginFeatureError.invalidAuthorizationCredential
  }

  guard let identityTokenData = credential.identityToken,
        let idToken = String(data: identityTokenData, encoding: .utf8) else {
    throw LoginFeatureError.invalidAuthorizationCredential
  }

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
public struct LoginFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var registrationStatus: RegistrationStatus = .unregistered
    public var loginStatus: LoginStatus = .unauthenticated
    public var isSigningIn: Bool = false
    public var isCompletingRegistration: Bool = false
    @Presents public var alert: AlertState<Action.Alert>?
    public var pendingUserData: User?

    public init() {}
  }

  public enum Action {
    case loginButtonTapped
    case loginResponse(Result<LoginResponse, Error>)
    case registrationResponse(Result<LoginResponse, Error>)
    case signInWithAppleButtonTapped(Result<ASAuthorization, Error>)
    case showError(AppError)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    @CasePathable
    public enum Alert: Equatable {
      case dismiss
    }

    @CasePathable
    public enum Delegate: Equatable {
      case loginCompleted
      case registrationCompleted
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.logger) var logger

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

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .loginButtonTapped:
        state.alert = nil
        state.isSigningIn = true
        return .none

      case let .loginResponse(.success(response)):
        state.isSigningIn = false
        guard let token = response.body?.token else {
          return .send(.showError(.loginFailed(reason: "Invalid response: missing token")))
        }
        let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
        logger.info(.auth, "LoginFeature: token received (\(token.count) chars): \(tokenPreview)")
        state.loginStatus = .authenticated
        let expirationDate = response.body?.expirationDate
        return .run { send in
          try await keychainClient.setJwtToken(token)
          if let expirationDate = expirationDate {
            try await keychainClient.setTokenExpiresAt(expirationDate)
          }
          let storedToken = try await keychainClient.getJwtToken()
          guard storedToken == token else {
            await send(.showError(.loginFailed(reason: "Failed to store authentication token")))
            return
          }
          await send(.delegate(.loginCompleted))
        }

      case let .registrationResponse(.success(response)):
        state.isSigningIn = false
        state.isCompletingRegistration = true
        guard let token = response.body?.token else {
          state.isCompletingRegistration = false
          return .send(.showError(.registrationFailed(reason: "Invalid response: missing token")))
        }
        let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
        logger.info(.auth, "LoginFeature: token received (\(token.count) chars): \(tokenPreview)")
        state.registrationStatus = .registered
        state.loginStatus = .authenticated
        let userData = state.pendingUserData
        let expirationDate = response.body?.expirationDate
        return .run { send in
          try await keychainClient.setJwtToken(token)
          if let expirationDate = expirationDate {
            try await keychainClient.setTokenExpiresAt(expirationDate)
          }
          let storedToken = try await keychainClient.getJwtToken()
          guard storedToken == token else {
            await send(.showError(.registrationFailed(reason: "Failed to store authentication token")))
            return
          }
          if let userData = userData {
            try await keychainClient.setUserData(userData)
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
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
