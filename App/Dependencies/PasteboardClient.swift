import ComposableArchitecture
import UIKit

@DependencyClient
struct PasteboardClient {
  var hasStrings: @Sendable () -> Bool = { false }
  var string: @Sendable () -> String? = { nil }
}

extension DependencyValues {
  var pasteboardClient: PasteboardClient {
    get { self[PasteboardClient.self] }
    set { self[PasteboardClient.self] = newValue }
  }
}

extension PasteboardClient: DependencyKey {
  static let liveValue = Self(
    hasStrings: {
      UIPasteboard.general.hasStrings
    },
    string: {
      UIPasteboard.general.string
    }
  )

  static let testValue = Self()
}
