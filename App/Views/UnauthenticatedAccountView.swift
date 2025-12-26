import SwiftUI

struct UnauthenticatedAccountView: View {
  let onSignInTapped: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()

        Image(systemName: "person.crop.circle.badge.questionmark")
          .font(.system(size: 80))
          .foregroundStyle(.secondary)

        Text("Sign In Required")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Sign in with your Apple ID to access your account settings and add new videos to your library.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)

        Button(action: onSignInTapped) {
          Label("Sign in with Apple", systemImage: "apple.logo")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 40)

        Spacer()
        Spacer()
      }
      .navigationTitle("Account")
    }
  }
}

#Preview {
  UnauthenticatedAccountView {
    print("Sign in tapped")
  }
}
