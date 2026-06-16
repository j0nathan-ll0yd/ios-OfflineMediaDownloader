import LifegamesTokens
import SwiftUI

/// Shared brand treatment for the OFFLINE / "media downloader" surfaces
/// (Launch, Login): a cyan→blue→pink wordmark gradient plus colorful neon
/// radial washes for the background.
public enum OMDBrand {
  public static let wordmarkGradient = LinearGradient(
    colors: [LGColor.accentCyan, LGColor.accentBlue, LGColor.accentPink],
    startPoint: .leading,
    endPoint: .trailing
  )

  public static var colorWashes: some View {
    ZStack {
      RadialGradient(
        colors: [LGColor.accentCyan.opacity(0.18), .clear],
        center: UnitPoint(x: 0.2, y: 0.22), startRadius: 0, endRadius: 300
      )
      RadialGradient(
        colors: [LGColor.accentPink.opacity(0.15), .clear],
        center: UnitPoint(x: 0.85, y: 0.8), startRadius: 0, endRadius: 320
      )
      RadialGradient(
        colors: [LGColor.accentPurple.opacity(0.12), .clear],
        center: UnitPoint(x: 0.5, y: 0.5), startRadius: 0, endRadius: 380
      )
    }
  }
}
