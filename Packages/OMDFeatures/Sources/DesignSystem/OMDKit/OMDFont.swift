import SwiftUI

/// Brand type: every OMD text style resolves to Space Grotesk (no system fonts).
///
/// The committed `SpaceGrotesk-Variable.ttf` exposes ONLY the family
/// `"Space Grotesk"` — the static PostScript names (`SpaceGrotesk-Bold`, etc.)
/// do NOT resolve and silently fall back to Helvetica. So every style addresses
/// the family and synthesizes weight from the variable `wght` axis, with Dynamic
/// Type support via `relativeTo:`.
///
/// `mono` keeps tabular figures for aligned numerics (sizes, durations, counts).
public enum OMDFont {
  private static let family = "Space Grotesk"

  public static func bold(_ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
    .custom(family, size: size, relativeTo: relativeTo).weight(.bold)
  }

  public static func semibold(_ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
    .custom(family, size: size, relativeTo: relativeTo).weight(.semibold)
  }

  public static func medium(_ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
    .custom(family, size: size, relativeTo: relativeTo).weight(.medium)
  }

  public static func regular(_ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
    .custom(family, size: size, relativeTo: relativeTo).weight(.regular)
  }

  public static func mono(_ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
    .custom(family, size: size, relativeTo: relativeTo).weight(.medium).monospacedDigit()
  }
}
