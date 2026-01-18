import SwiftUI

/// A blocking overlay that displays while waiting for the first progress event
/// from a background download. This prevents the app from going to background
/// before the download has properly started.
struct DownloadInitiatingOverlay: View {
  let title: String
  @State private var pulseScale: CGFloat = 1.0
  @State private var iconRotation: Double = 0

  private let theme = DarkProfessionalTheme()

  var body: some View {
    ZStack {
      // Semi-transparent blocking background
      Color.black.opacity(0.85)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        // Animated download icon
        ZStack {
          // Pulsing circle background
          Circle()
            .fill(
              LinearGradient(
                colors: [theme.primaryColor.opacity(0.3), theme.accentColor.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 100, height: 100)
            .scaleEffect(pulseScale)

          // Download icon
          Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(
              LinearGradient(
                colors: [theme.primaryColor, theme.accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .rotationEffect(.degrees(iconRotation))
        }

        VStack(spacing: 12) {
          Text("Starting Download")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(theme.textPrimary)

          Text(title)
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)

          // Progress spinner
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryColor))
            .scaleEffect(1.2)
            .padding(.top, 8)

          Text("Please wait...")
            .font(.caption)
            .foregroundStyle(theme.textSecondary.opacity(0.7))
            .padding(.top, 4)
        }
      }
      .padding(32)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(theme.surfaceColor)
          .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
      )
    }
    .onAppear {
      // Start pulse animation
      withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
        pulseScale = 1.15
      }
      // Subtle rotation animation
      withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
        iconRotation = 10
      }
    }
    .preferredColorScheme(.dark)
  }
}

#Preview {
  DownloadInitiatingOverlay(title: "My Video Title - Episode 1.mp4")
}
