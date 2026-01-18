import UIKit
import SwiftUI
import AuthenticationServices
import ComposableArchitecture
import Valet

// MARK: - LoginView
// Feature: App/Features/LoginFeature.swift

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
      if store.isSigningIn || store.isCompletingRegistration {
        Color.black.opacity(0.5)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(theme.primaryColor)
          Text(store.isCompletingRegistration ? "Setting up account..." : "Signing in...")
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
