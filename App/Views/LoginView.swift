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
    var isSigningIn: Bool = false
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
          debugPrint("LoginFeature: token stored, sending delegate")
          await send(.delegate(.loginCompleted))
        }

      case let .registrationResponse(.success(response)):
        debugPrint("LoginFeature: registrationResponse success, body: \(String(describing: response.body))")
        state.isSigningIn = false
        guard let token = response.body?.token else {
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
          debugPrint("LoginFeature: token stored")
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

struct LoginView: View {
  @Bindable var store: StoreOf<LoginFeature>

  private let theme = DarkProfessionalTheme()

  /// Computed welcome subtitle based on registration status
  private var welcomeSubtitle: String {
    if store.registrationStatus == .registered {
      // Could show user name here if we had it in state
      return "Welcome back"
    } else {
      return "Sign in to get started"
    }
  }

  var body: some View {
    ZStack {
      // Dark background
      theme.backgroundColor
        .ignoresSafeArea()

      // Abstract background shapes
      GeometryReader { geometry in
        ZStack {
          Circle()
            .fill(theme.primaryColor.opacity(0.1))
            .frame(width: 300, height: 300)
            .blur(radius: 60)
            .offset(x: -100, y: -200)

          Circle()
            .fill(theme.accentColor.opacity(0.1))
            .frame(width: 250, height: 250)
            .blur(radius: 50)
            .offset(x: 150, y: 100)
        }
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer()

        // Welcome text
        VStack(spacing: 8) {
          Text("Welcome")
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(.white)

          Text(welcomeSubtitle)
            .font(.title3)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(.bottom, 40)

        // Logo
        LifegamesLogo(size: .medium, showSubtitle: false, animated: true)
          .padding(.bottom, 60)

        // Auth buttons
        VStack(spacing: 14) {
          // Sign in with Apple - native button styled for dark mode
          SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = ""
            request.state = ""
            store.send(.loginButtonTapped)
          } onCompletion: { result in
            switch result {
            case .success(let authorization):
              store.send(.signInWithAppleButtonTapped(.success(authorization)))
            case .failure(let error):
              store.send(.signInWithAppleButtonTapped(.failure(error)))
            }
          }
          .signInWithAppleButtonStyle(.white)
          .frame(height: 54)
          .clipShape(Capsule())

          // Disabled Google button (Coming Soon)
          AuthButton(provider: .google, style: .dark) { }
            .disabled(true)
            .opacity(0.5)

          // Disabled Email button (Coming Soon)
          AuthButton(provider: .email, style: .dark) { }
            .disabled(true)
            .opacity(0.5)
        }
        .padding(.horizontal, 32)
        .disabled(store.isSigningIn)
        .opacity(store.isSigningIn ? 0.6 : 1.0)

        Spacer()

        // Footer
        VStack(spacing: 8) {
          Text("By continuing, you agree to our")
            .font(.caption)
            .foregroundStyle(theme.textSecondary)

          HStack(spacing: 4) {
            Button("Terms") { }
              .font(.caption)
              .fontWeight(.medium)
              .foregroundStyle(theme.primaryColor)

            Text("and")
              .font(.caption)
              .foregroundStyle(theme.textSecondary)

            Button("Privacy Policy") { }
              .font(.caption)
              .fontWeight(.medium)
              .foregroundStyle(theme.primaryColor)
          }
        }
        .padding(.bottom, 32)
      }

      // Loading overlay
      if store.isSigningIn {
        Color.black.opacity(0.5)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(theme.primaryColor)
          Text("Signing in...")
            .font(.subheadline)
            .foregroundStyle(.white)
        }
        .padding(24)
        .background(DarkProfessionalTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      }
    }
    .preferredColorScheme(.dark)
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

#Preview {
  LoginView(
    store: Store(initialState: LoginFeature.State()) {
      LoginFeature()._printChanges()
    }
  )
}
