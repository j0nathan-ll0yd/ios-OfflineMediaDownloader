import AuthenticationServices
import ComposableArchitecture
import DesignSystem
import LifegamesComponentsCore
import LifegamesTemplates
import LifegamesTokens
import SwiftUI

// MARK: - LoginView

public struct LoginView: View {
  @Bindable var store: StoreOf<LoginFeature>
  @State private var appleController = AppleSignInController()

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  /// Computed welcome subtitle based on registration status
  private var welcomeSubtitle: String {
    if store.registrationStatus == .registered {
      "Welcome back"
    } else {
      "Sign in to access your offline library"
    }
  }

  public var body: some View {
    ZStack {
      AuthTemplate(
        title: nil,
        accent: OMDPalette.primary,
        branding: { branding },
        primaryAction: { primaryAction },
        footer: { footer },
        background: {
          ZStack {
            LinearGradient(
              colors: [LGColor.surfaceDeep, LGColor.surfaceBase],
              startPoint: .top,
              endPoint: .bottom
            )
            OMDBrand.colorWashes
          }
        }
      )

      if store.isSigningIn || store.isCompletingRegistration {
        loadingOverlay
      }
    }
    .preferredColorScheme(.dark)
    .alert($store.scope(state: \.alert, action: \.alert))
    .sheet(item: $store.scope(state: \.emailLogin, action: \.emailLogin)) { emailStore in
      NavigationStack {
        EmailLoginView(store: emailStore)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button("Cancel") {
                store.send(.emailLogin(.dismiss))
              }
              .foregroundStyle(LGColor.textTitle)
            }
          }
      }
      .presentationDetents([.medium, .large])
    }
  }

  // MARK: - Branding

  private var branding: some View {
    VStack(spacing: 0) {
      VStack(spacing: Spacing.s300) {
        Text("WELCOME")
          .font(OMDFont.bold(34))
          .tracking(6)
          .foregroundStyle(OMDBrand.wordmarkGradient)
          .shadow(color: LGColor.accentBlue.opacity(0.5), radius: 14)

        Text(welcomeSubtitle)
          .font(OMDFont.regular(14))
          .foregroundStyle(LGColor.textMuted)
          .multilineTextAlignment(.center)
      }

      BufferRingAnimation()
        .frame(height: 170)
        .padding(.top, Spacing.s600)
    }
  }

  // MARK: - Primary Action

  private var primaryAction: some View {
    VStack(spacing: Spacing.s300) {
      appleButton
      emailButton
    }
    .disabled(store.isSigningIn)
    .opacity(store.isSigningIn ? 0.6 : 1.0)
  }

  /// Custom gradient-bordered button that drives the REAL Sign in with Apple
  /// flow via `AppleSignInController` (so it can be styled beyond the native
  /// button's fixed appearance).
  private var appleButton: some View {
    Button {
      store.send(.loginButtonTapped)
      appleController.start { result in
        switch result {
        case let .success(authorization):
          store.send(.signInWithAppleButtonTapped(.success(authorization)))
        case let .failure(error):
          store.send(.signInWithAppleButtonTapped(.failure(error)))
        }
      }
    } label: {
      HStack(spacing: Spacing.s300) {
        Image(systemName: "apple.logo")
          .font(.system(size: 18))
        Text("Sign in with Apple")
          .font(OMDFont.semibold(16))
      }
      .foregroundStyle(LGColor.textTitle)
      .frame(maxWidth: .infinity)
      .padding(.vertical, Spacing.s400)
      .background(LGColor.surfaceRaised)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(OMDBrand.wordmarkGradient, lineWidth: 1.5)
      )
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(color: LGColor.accentBlue.opacity(0.5), radius: 10)
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(.rect)
    .accessibilityLabel("Sign in with Apple")
  }

  /// Secondary outline button that opens the email-entry sheet.
  private var emailButton: some View {
    Button {
      store.send(.emailButtonTapped)
    } label: {
      HStack(spacing: Spacing.s300) {
        Image(systemName: "envelope.fill")
          .font(.system(size: 16))
        Text("Continue with Email")
          .font(OMDFont.semibold(16))
      }
      .foregroundStyle(LGColor.textPrimary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, Spacing.s400)
      .background(LGColor.surfaceRaised.opacity(0.6))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(LGColor.borderSubtle, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(.rect)
    .accessibilityLabel("Continue with Email")
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: Spacing.s200) {
      Text("By continuing, you agree to our")
        .font(OMDFont.regular(11))
        .foregroundStyle(LGColor.textMuted)

      HStack(spacing: 4) {
        Button("Terms") {}
          .font(OMDFont.medium(11))
          .foregroundStyle(OMDPalette.primary)

        Text("and")
          .font(OMDFont.regular(11))
          .foregroundStyle(LGColor.textMuted)

        Button("Privacy Policy") {}
          .font(OMDFont.medium(11))
          .foregroundStyle(OMDPalette.primary)
      }

      Text("Secure authentication via Apple ID")
        .font(OMDFont.regular(10))
        .foregroundStyle(LGColor.textSubtle)
        .padding(.top, Spacing.s100)
    }
  }

  // MARK: - Loading Overlay

  private var loadingOverlay: some View {
    ZStack {
      Color.black.opacity(0.5)
        .ignoresSafeArea()

      VStack(spacing: Spacing.s400) {
        ProgressView()
          .scaleEffect(1.2)
          .tint(OMDPalette.primary)
        Text(store.isCompletingRegistration ? "Setting up account..." : "Signing in...")
          .font(OMDFont.medium(14))
          .foregroundStyle(LGColor.textTitle)
      }
      .padding(Spacing.s600)
      .background(LGColor.surfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
  }
}

// MARK: - Preview

#Preview {
  LoginView(
    store: Store(initialState: LoginFeature.State()) {
      LoginFeature()
    }
  )
  .preferredColorScheme(.dark)
}
