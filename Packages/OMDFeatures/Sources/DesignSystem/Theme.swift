import SwiftUI

// MARK: - Theme Protocol

public protocol Theme {
  var name: String { get }
  var primaryGradient: LinearGradient { get }
  var backgroundColor: Color { get }
  var surfaceColor: Color { get }
  var primaryColor: Color { get }
  var accentColor: Color { get }
  var textPrimary: Color { get }
  var textSecondary: Color { get }
  var successColor: Color { get }
  var warningColor: Color { get }
  var errorColor: Color { get }
  var isDark: Bool { get }
}

// MARK: - V6 Lifegames Pro Theme (Dark Professional)

public struct DarkProfessionalTheme: Theme {
  public let name = "Lifegames Pro"

  public let primaryGradient = LinearGradient(
    colors: [Color(hex: "121212"), Color(hex: "1E1E1E")],
    startPoint: .top,
    endPoint: .bottom
  )

  public let backgroundColor = Color(hex: "121212")
  public let surfaceColor = Color(hex: "1E1E1E")
  public let primaryColor = Color(hex: "007AFF")
  public let accentColor = Color(hex: "5E5CE6")
  public let textPrimary = Color.white
  public let textSecondary = Color(hex: "8E8E93")
  public let successColor = Color(hex: "34C759")
  public let warningColor = Color(hex: "FF9F0A")
  public let errorColor = Color(hex: "FF453A")
  public let isDark = true

  // Additional dark mode colors
  public static let cardBackground = Color(hex: "2C2C2E")
  public static let divider = Color(hex: "38383A")

  public init() {}
}

// MARK: - Color Extension for Hex

public extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

// MARK: - Card Style Modifier

public struct CardStyle: ViewModifier {
  let theme: any Theme

  public init(theme: any Theme) {
    self.theme = theme
  }

  public func body(content: Content) -> some View {
    content
      .background(theme.surfaceColor)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(color: .black.opacity(theme.isDark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
  }
}

public extension View {
  func cardStyle(theme: any Theme) -> some View {
    modifier(CardStyle(theme: theme))
  }
}

// MARK: - Preview

#Preview("Lifegames Pro Theme") {
  let theme = DarkProfessionalTheme()

  ScrollView {
    VStack(spacing: 24) {
      // Theme info
      VStack(alignment: .leading, spacing: 8) {
        Text(theme.name)
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(.white)

        Text("Dark professional theme for V6 Lifegames Pro")
          .font(.subheadline)
          .foregroundStyle(theme.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(DarkProfessionalTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      // Color palette
      VStack(alignment: .leading, spacing: 12) {
        Text("COLOR PALETTE")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(theme.textSecondary)

        HStack(spacing: 12) {
          colorSwatch(name: "Primary", color: theme.primaryColor)
          colorSwatch(name: "Accent", color: theme.accentColor)
          colorSwatch(name: "Success", color: theme.successColor)
          colorSwatch(name: "Warning", color: theme.warningColor)
          colorSwatch(name: "Error", color: theme.errorColor)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Gradient preview
      VStack(alignment: .leading, spacing: 8) {
        Text("GRADIENT")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(theme.textSecondary)

        RoundedRectangle(cornerRadius: 12)
          .fill(LinearGradient(
            colors: [theme.primaryColor, theme.accentColor],
            startPoint: .leading,
            endPoint: .trailing
          ))
          .frame(height: 60)
      }
    }
    .padding()
  }
  .background(theme.backgroundColor)
  .preferredColorScheme(.dark)
}

private func colorSwatch(name: String, color: Color) -> some View {
  VStack(spacing: 4) {
    Circle()
      .fill(color)
      .frame(width: 40, height: 40)
    Text(name)
      .font(.caption2)
      .foregroundStyle(.secondary)
  }
}
