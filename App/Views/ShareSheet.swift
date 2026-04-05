import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIActivityViewController to share content
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  var excludedActivityTypes: [UIActivity.ActivityType]?

  func makeUIViewController(context _: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: items,
      applicationActivities: nil
    )
    controller.excludedActivityTypes = excludedActivityTypes
    return controller
  }

  func updateUIViewController(_: UIActivityViewController, context _: Context) {
    // No updates needed
  }
}

#Preview {
  ShareSheet(items: ["Sample text to share"])
}
