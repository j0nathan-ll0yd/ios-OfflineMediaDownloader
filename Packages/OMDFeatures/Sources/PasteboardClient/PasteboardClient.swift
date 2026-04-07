import ComposableArchitecture
import UIKit

@DependencyClient
public struct PasteboardClient: Sendable {
  public var hasStrings: @Sendable () -> Bool = { false }
  public var string: @Sendable () -> String? = { nil }
}

public extension DependencyValues {
  var pasteboardClient: PasteboardClient {
    get { self[PasteboardClient.self] }
    set { self[PasteboardClient.self] = newValue }
  }
}

extension PasteboardClient: DependencyKey {
  public static let liveValue = Self(
    hasStrings: {
      UIPasteboard.general.hasStrings
    },
    string: {
      UIPasteboard.general.string
    }
  )

  public static let testValue = Self()
}
