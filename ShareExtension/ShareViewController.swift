import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
  private var hostingController: UIHostingController<ShareExtensionView>?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x12 / 255.0, alpha: 1)

    let shareView = ShareExtensionView(
      extensionContext: extensionContext,
      onComplete: { [weak self] in self?.completeRequest() },
      onCancel: { [weak self] in self?.cancelRequest() }
    )

    let hosting = UIHostingController(rootView: shareView)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    hosting.view.backgroundColor = .clear

    addChild(hosting)
    view.addSubview(hosting.view)
    hosting.didMove(toParent: self)

    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    hostingController = hosting
  }

  // MARK: - Request Lifecycle

  private func completeRequest() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func cancelRequest() {
    extensionContext?.cancelRequest(withError: NSError(
      domain: "com.lifegames.OfflineMediaDownloader.ShareExtension",
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
    ))
  }
}

// MARK: - URL Extraction

extension ShareViewController {
  /// Extracts the first valid YouTube URL from the extension context's input items.
  /// Handles both UTType.url (Safari/most apps) and UTType.plainText (YouTube app shares as text).
  static func extractURL(from extensionContext: NSExtensionContext?) async -> URL? {
    guard let extensionContext else { return nil }

    for item in extensionContext.inputItems as? [NSExtensionItem] ?? [] {
      guard let attachments = item.attachments else { continue }

      // Try URL type first
      for provider in attachments {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
            if YouTubeURLValidator.validate(url) { return url }
          }
        }
      }

      // Fall back to plain text (YouTube app shares URL as text)
      for provider in attachments {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
             let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
             YouTubeURLValidator.validate(url)
          {
            return url
          }
        }
      }
    }

    return nil
  }
}
