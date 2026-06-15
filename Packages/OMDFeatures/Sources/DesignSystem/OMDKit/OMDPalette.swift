import LifegamesTokens
import SwiftUI

/// Color by MEANING, not decoration — this app saves videos for offline play:
///   primary / download = blue · playback & identity = cyan · complete = green
///   queued / storage = amber · destructive = pink · description / library = purple
public enum OMDPalette {
  public static let primary = LGColor.accentBlue
  public static let playback = LGColor.accentCyan
  public static let complete = LGColor.accentGreen
  public static let queued = LGColor.accentAmber
  public static let destructive = LGColor.accentPink
  public static let content = LGColor.accentPurple
}
