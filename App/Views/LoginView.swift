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

@Reducer
struct LoginFeature: Reducer {
  @ObservableState
  struct State: Equatable {
    var registrationStatus: RegistrationStatus = .unregistered
    var loginStatus: LoginStatus = .unauthenticated
    var errorMessage: String?
    var pendingUserData: User?
  }

  enum Action {
    case loginButtonTapped
    case loginResponse(Result<LoginResponse, Error>)
    case registrationResponse(Result<LoginResponse, Error>)
    case signInWithAppleButtonTapped(Result<ASAuthorization, Error>)
    case delegate(Delegate)

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
        try await self.serverClient.registerUser(userData: userData, idToken: data.idToken)
      }))
    } else {
      await send(.loginResponse(Result {
        try await self.serverClient.loginUser(idToken: data.idToken)
      }))
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .loginButtonTapped:
        state.errorMessage = nil
        return .none

      case let .loginResponse(.success(response)):
        debugPrint("LoginFeature: loginResponse success, body: \(String(describing: response.body))")
        guard let token = response.body?.token else {
          state.errorMessage = "Invalid response: missing token"
          return .none
        }
        let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
        print("🔑 LoginFeature: token received (\(token.count) chars): \(tokenPreview)")
        state.loginStatus = .authenticated
        return .run { send in
          debugPrint("LoginFeature: storing token in keychain")
          try await keychainClient.setJwtToken(token)
          debugPrint("LoginFeature: token stored, sending delegate")
          await send(.delegate(.loginCompleted))
        }

      case let .registrationResponse(.success(response)):
        debugPrint("LoginFeature: registrationResponse success, body: \(String(describing: response.body))")
        guard let token = response.body?.token else {
          state.errorMessage = "Invalid response: missing token"
          return .none
        }
        let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
        print("🔑 LoginFeature: token received (\(token.count) chars): \(tokenPreview)")
        state.registrationStatus = .registered
        state.loginStatus = .authenticated
        let userData = state.pendingUserData
        return .run { send in
          debugPrint("LoginFeature: storing token in keychain")
          try await keychainClient.setJwtToken(token)
          debugPrint("LoginFeature: token stored")
          if let userData = userData {
            try await keychainClient.setUserData(userData)
            debugPrint("LoginFeature: userData stored")
          }
          await send(.delegate(.registrationCompleted))
        }

      case let .loginResponse(.failure(error)):
        state.errorMessage = error.localizedDescription
        return .none

      case let .registrationResponse(.failure(error)):
        state.errorMessage = error.localizedDescription
        return .none

      case let .signInWithAppleButtonTapped(.success(result)):
        // Store pending user data for registration
        if let data = try? handleLoginSuccess(authorization: result) {
          state.pendingUserData = data.userData
        }
        return .run { send in
          try await dispatchAuthCode(send: send, result: result)
        }.cancellable(id: CancelID.signIn, cancelInFlight: true)

      case let .signInWithAppleButtonTapped(.failure(error)):
        state.errorMessage = error.localizedDescription
        return .none

      case .delegate:
        // Delegate actions are handled by parent
        return .none
      }
    }
  }
}

struct LoginView: View {
  @Bindable var store: StoreOf<LoginFeature>

  var body: some View {
    ZStack {
      yellow.edgesIgnoringSafeArea(.all)
      VStack {
        if store.errorMessage != nil {
          ErrorMessageView(message: store.errorMessage!)
          Spacer().frame(height: 25)
        }
        RegistrationStatusView(status: store.registrationStatus)
        Spacer().frame(height: 25)
        LoginStatusView(status: store.loginStatus)
        Spacer().frame(height: 25)
        LogoView()
        VStack {
          SignInWithAppleButton(
            .continue,
            onRequest: { request in
              request.requestedScopes = [.fullName, .email]
              request.nonce = ""
              request.state = ""
              store.send(.loginButtonTapped)
            },
            onCompletion: { result in
              switch result {
              case .success(let authorization):
                store.send(.signInWithAppleButtonTapped(.success(authorization)))
              case .failure(let error):
                store.send(.signInWithAppleButtonTapped(.failure(error)))
              }
            }
          )
        }
        .signInWithAppleButtonStyle(.black)
        .frame(width: 250, height: 50)
      }
    }
  }
}

#Preview {
  LoginView(
    store: Store(initialState: LoginFeature.State()) {
      LoginFeature()._printChanges()
    }
  )
}
