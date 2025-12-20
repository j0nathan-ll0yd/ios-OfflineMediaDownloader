import SwiftUI

// MARK: - Logo Size

enum LogoSize {
    case small, medium, large

    var iconSize: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 80
        case .large: return 120
        }
    }

    var titleFont: Font {
        switch self {
        case .small: return .headline
        case .medium: return .title2
        case .large: return .largeTitle
        }
    }

    var subtitleFont: Font {
        switch self {
        case .small: return .caption
        case .medium: return .subheadline
        case .large: return .title3
        }
    }
}

// MARK: - Lifegames Logo Component

struct LifegamesLogo: View {
    var size: LogoSize = .large
    var showSubtitle: Bool = true
    var animated: Bool = false

    @State private var isPulsing = false

    private let theme = DarkProfessionalTheme()

    var body: some View {
        VStack(spacing: size == .large ? 16 : 8) {
            logoIcon
            logoText
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - Logo Icon

    private var logoIcon: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [theme.primaryColor, theme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: size.iconSize, height: size.iconSize)
                .scaleEffect(isPulsing ? 1.05 : 1.0)

            // Inner circle
            Circle()
                .fill(DarkProfessionalTheme.cardBackground)
                .frame(width: size.iconSize - 12, height: size.iconSize - 12)

            // "L" monogram
            Text("L")
                .font(.system(size: size.iconSize * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.primaryColor)
        }
    }

    // MARK: - Logo Text

    private var logoText: some View {
        VStack(spacing: 4) {
            Text("Lifegames")
                .font(size.titleFont)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            if showSubtitle {
                Text("Media Downloader")
                    .font(size.subtitleFont)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Preview

#Preview("Lifegames Logo") {
    let theme = DarkProfessionalTheme()

    VStack(spacing: 40) {
        ZStack {
            theme.backgroundColor
            LifegamesLogo(size: .large, animated: true)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16))

        HStack(spacing: 32) {
            LifegamesLogo(size: .small, showSubtitle: false, animated: true)
            LifegamesLogo(size: .medium, showSubtitle: false, animated: true)
        }
        .padding()
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
    .preferredColorScheme(.dark)
}
