import SwiftUI

// MARK: - Lifegames Pro - Launch View

struct LifegamesLaunchView: View {
    var status: String = "Loading..."
    @State private var dotOffset: CGFloat = 0
    @State private var showShapes = false

    private let theme = DarkProfessionalTheme()

    var body: some View {
        ZStack {
            // Dark background
            theme.backgroundColor
                .ignoresSafeArea()

            // Floating geometric shapes
            GeometryReader { geometry in
                ZStack {
                    // Blue circle
                    Circle()
                        .fill(theme.primaryColor.opacity(0.25))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .offset(x: showShapes ? -50 : -80, y: -150)
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: showShapes)

                    // Purple circle
                    Circle()
                        .fill(theme.accentColor.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .blur(radius: 35)
                        .offset(x: showShapes ? 100 : 130, y: 50)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: showShapes)

                    // Teal circle
                    Circle()
                        .fill(Color(hex: "5AC8FA").opacity(0.15))
                        .frame(width: 150, height: 150)
                        .blur(radius: 30)
                        .offset(x: showShapes ? -80 : -50, y: 200)
                        .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: showShapes)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
                LifegamesLogo(size: .large, animated: true)

                Spacer()

                // Animated loading dots
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.primaryColor, theme.accentColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 12, height: 12)
                                .offset(y: dotOffset)
                                .animation(
                                    .easeInOut(duration: 0.4)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.15),
                                    value: dotOffset
                                )
                        }
                    }

                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            showShapes = true
            dotOffset = -10
        }
    }
}

// MARK: - Preview

#Preview("Launch - Loading") {
    LifegamesLaunchView(status: "Checking authentication...")
}

#Preview("Launch - Connecting") {
    LifegamesLaunchView(status: "Connecting to server...")
}
