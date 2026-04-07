import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIActivityViewController to share content
public struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  var excludedActivityTypes: [UIActivity.ActivityType]?

  public init(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
    self.items = items
    self.excludedActivityTypes = excludedActivityTypes
  }

  public func makeUIViewController(context _: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: items,
      applicationActivities: nil
    )
    controller.excludedActivityTypes = excludedActivityTypes
    return controller
  }

  public func updateUIViewController(_: UIActivityViewController, context _: Context) {
    // No updates needed
  }
}
