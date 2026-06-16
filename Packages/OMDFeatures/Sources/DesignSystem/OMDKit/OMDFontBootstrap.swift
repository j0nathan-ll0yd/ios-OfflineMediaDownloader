import LifegamesTokens

/// Re-export shim so the app target can register the Space Grotesk fonts at
/// launch without linking `LifegamesTokens` directly.
public enum OMDFontBootstrap {
  @MainActor public static func registerFonts() {
    LifegamesFonts.registerFonts()
  }
}
