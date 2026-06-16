import AuthenticationServices
import ComposableArchitecture
import DesignSystem
import LifegamesComponents
import LifegamesComponentsCore
import LifegamesTemplates
import LifegamesTokens
import SwiftUI

// MARK: - LoginView

public struct LoginView: View {
  @Bindable var store: StoreOf<LoginFeature>

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
  }

  // MARK: - Branding

  private var branding: some View {
    VStack(spacing: Spacing.s600) {
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

      LifegamesLogo(size: .medium, showSubtitle: false, animated: true)
    }
  }

  // MARK: - Primary Action (REAL Sign in with Apple — ported verbatim)

  private var primaryAction: some View {
    VStack(spacing: 14) {
      // Sign in with Apple - native button styled for dark mode
      SignInWithAppleButton(.continue) { request in
        request.requestedScopes = [.fullName, .email]
        request.nonce = ""
        request.state = ""
        store.send(.loginButtonTapped)
      } onCompletion: { result in
        switch result {
        case let .success(authorization):
          store.send(.signInWithAppleButtonTapped(.success(authorization)))
        case let .failure(error):
          store.send(.signInWithAppleButtonTapped(.failure(error)))
        }
      }
      .signInWithAppleButtonStyle(.white)
      .frame(height: 54)
      .clipShape(Capsule())

      // Disabled Google button (Coming Soon)
      AuthButton(provider: .google, style: .dark) {}
        .disabled(true)
        .opacity(0.5)

      // Disabled Email button (Coming Soon)
      AuthButton(provider: .email, style: .dark) {}
        .disabled(true)
        .opacity(0.5)
    }
    .disabled(store.isSigningIn)
    .opacity(store.isSigningIn ? 0.6 : 1.0)
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
