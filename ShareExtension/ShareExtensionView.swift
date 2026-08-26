import SwiftUI

// MARK: - ShareExtensionView

/// Owns the share submission effect and drives `ShareStatusView`.
///
/// Rendering lives in `ShareStatusView` so the three visual states stay
/// renderable without an `NSExtensionContext`.
struct ShareExtensionView: View {
  let extensionContext: NSExtensionContext?
  let onComplete: () -> Void
  let onCancel: () -> Void

  @State private var status: ShareStatus = .progress

  var body: some View {
    ShareStatusView(status: status, onDismiss: onCancel)
      .task {
        await handleShare()
      }
  }

  // MARK: - Share Handling

  private func handleShare() async {
    guard let url = await ShareViewController.extractURL(from: extensionContext) else {
      status = .failure("No valid YouTube URL found in shared content.")
      return
    }

    do {
      try await ShareService.submitURL(url)
      status = .success
      try? await Task.sleep(for: .seconds(1.5))
      onComplete()
    } catch {
      status = .failure(error.localizedDescription)
    }
  }
}

// MARK: - Preview

#Preview {
  ShareExtensionView(
    extensionContext: nil,
    onComplete: {},
    onCancel: {}
  )
  .preferredColorScheme(.dark)
}
