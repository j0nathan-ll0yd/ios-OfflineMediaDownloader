import SwiftUI
import AuthenticationServices

// MARK: - Auth Provider

public enum AuthProvider: CaseIterable, Identifiable, Sendable {
    case apple
    case google
    case email

    public var id: String { name }

    public var name: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "Email"
        }
    }

    public var buttonLabel: String {
        switch self {
        case .apple: return "Sign in with Apple"
        case .google: return "Continue with Google"
        case .email: return "Continue with Email"
        }
    }
}

// MARK: - Auth Button Style

public enum AuthButtonStyle: Sendable {
    case light
    case dark
}

// MARK: - Auth Button Component

public struct AuthButton: View {
    let provider: AuthProvider
    let style: AuthButtonStyle
    var isLoading: Bool = false
    let action: () -> Void

    private let theme = DarkProfessionalTheme()

    public init(provider: AuthProvider, style: AuthButtonStyle, isLoading: Bool = false, action: @escaping () -> Void) {
        self.provider = provider
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(style == .dark ? .white : theme.primaryColor)
                } else {
                    providerIcon
                        .foregroundStyle(iconColor)
                }
                Text(provider.buttonLabel)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(backgroundColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Styling

    private var iconColor: Color {
        switch provider {
        case .apple:
            return style == .dark ? .white : .black
        case .google, .email:
            return theme.primaryColor
        }
    }

    private var textColor: Color {
        style == .dark ? .white : theme.textPrimary
    }

    @ViewBuilder
    private var backgroundColor: some View {
        if style == .dark {
            RoundedRectangle(cornerRadius: 27)
                .fill(provider == .apple ? Color.white.opacity(0.1) : DarkProfessionalTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 27)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .medium))
        case .google:
            Text("G")
                .font(.system(size: 18, weight: .bold, design: .rounded))
        case .email:
            Image(systemName: "envelope.fill")
                .font(.system(size: 18))
        }
    }
}

// MARK: - Auth Button Stack

public struct AuthButtonStack: View {
    let style: AuthButtonStyle
    let providers: [AuthProvider]
    var spacing: CGFloat = 12
    let onProviderSelected: (AuthProvider) -> Void

    public init(style: AuthButtonStyle, providers: [AuthProvider], spacing: CGFloat = 12, onProviderSelected: @escaping (AuthProvider) -> Void) {
        self.style = style
        self.providers = providers
        self.spacing = spacing
        self.onProviderSelected = onProviderSelected
    }

    public var body: some View {
        VStack(spacing: spacing) {
            ForEach(providers) { provider in
                AuthButton(
                    provider: provider,
                    style: style,
                    action: { onProviderSelected(provider) }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Auth Buttons") {
    let theme = DarkProfessionalTheme()

    VStack(spacing: 24) {
        VStack(spacing: 12) {
            Text("Dark Style")
                .font(.headline)
                .foregroundStyle(.white)
            AuthButtonStack(style: .dark, providers: AuthProvider.allCases) { _ in }
        }
        .padding()
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
    .preferredColorScheme(.dark)
}
