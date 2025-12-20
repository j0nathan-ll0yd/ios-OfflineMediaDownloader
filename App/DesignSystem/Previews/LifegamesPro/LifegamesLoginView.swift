import SwiftUI
import AuthenticationServices

// MARK: - Lifegames Pro - Login View

struct LifegamesLoginView: View {
    /// The user's name if registered (nil if not registered)
    var registeredUserName: String? = nil
    var isLoading: Bool = false
    var onSignInWithApple: ((ASAuthorizationAppleIDRequest) -> Void)?
    var onAppleSignInComplete: ((Result<ASAuthorization, Error>) -> Void)?

    private let theme = DarkProfessionalTheme()

    /// Computed welcome message based on registration status
    private var welcomeTitle: String {
        "Welcome"
    }

    private var welcomeSubtitle: String {
        if let name = registeredUserName, !name.isEmpty {
            return name
        } else {
            return "Sign in to get started"
        }
    }

    var body: some View {
        ZStack {
            // Dark background with subtle gradient overlay
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

                // Dynamic welcome text based on registration status
                VStack(spacing: 8) {
                    Text(welcomeTitle)
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
                        onSignInWithApple?(request)
                    } onCompletion: { result in
                        onAppleSignInComplete?(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(Capsule())

                    AuthButton(provider: .google, style: .dark) {
                        // Google sign-in action
                    }

                    AuthButton(provider: .email, style: .dark) {
                        // Email sign-in action
                    }
                }
                .padding(.horizontal, 32)
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1.0)

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

                #if DEBUG
                debugIndicator
                #endif
            }

            // Loading overlay
            if isLoading {
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
    }

    #if DEBUG
    private var debugIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(theme.successColor)
                .frame(width: 6, height: 6)
            Text("Debug")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.bottom, 8)
    }
    #endif
}

// MARK: - Preview

#Preview("Login - Not Registered") {
    LifegamesLoginView(registeredUserName: nil)
}

#Preview("Login - Registered User") {
    LifegamesLoginView(registeredUserName: "Jonathan Lloyd")
}

#Preview("Login - Loading") {
    LifegamesLoginView(registeredUserName: "Jonathan Lloyd", isLoading: true)
}
