import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIActivityViewController to share content
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  var excludedActivityTypes: [UIActivity.ActivityType]? = nil

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: items,
      applicationActivities: nil
    )
    controller.excludedActivityTypes = excludedActivityTypes
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // No updates needed
  }
}

#Preview {
  ShareSheet(items: ["Sample text to share"])
}
