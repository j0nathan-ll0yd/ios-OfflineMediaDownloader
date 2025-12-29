import SwiftUI

struct UnauthenticatedAccountView: View {
  let onSignInTapped: () -> Void

  private let theme = DarkProfessionalTheme()

  var body: some View {
    NavigationStack {
      ZStack {
        theme.backgroundColor
          .ignoresSafeArea()

        VStack(spacing: 24) {
          Spacer()

          // Icon with gradient background
          ZStack {
            Circle()
              .fill(
                LinearGradient(
                  colors: [theme.primaryColor.opacity(0.3), theme.accentColor.opacity(0.2)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 120, height: 120)

            Image(systemName: "person.crop.circle")
              .font(.system(size: 60))
              .foregroundStyle(
                LinearGradient(
                  colors: [theme.primaryColor, theme.accentColor],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
          }

          VStack(spacing: 12) {
            Text("Sign In Required")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundStyle(.white)

            Text("Sign in with your Apple ID to access your account settings and add new videos to your library.")
              .font(.body)
              .foregroundStyle(theme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
          }

          // Gradient sign in button
          Button(action: onSignInTapped) {
            HStack(spacing: 8) {
              Image(systemName: "apple.logo")
              Text("Sign in with Apple")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              LinearGradient(
                colors: [theme.primaryColor, theme.accentColor],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .clipShape(Capsule())
          }
          .padding(.horizontal, 40)

          Spacer()
          Spacer()
        }
      }
      .navigationTitle("Account")
      .navigationBarTitleDisplayMode(.large)
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .preferredColorScheme(.dark)
  }
}

#Preview {
  UnauthenticatedAccountView {
    print("Sign in tapped")
  }
}
