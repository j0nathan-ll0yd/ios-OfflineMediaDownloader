import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private let feedlyService = FeedlyService()
    private var hostingController: UIHostingController<ShareExtensionView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        showStatus(.loading)
        processSharedContent()
    }

    private func showStatus(_ status: ShareExtensionView.Status) {
        let contentView = ShareExtensionView(status: status) { [weak self] in
            self?.dismissExtension()
        }

        if let hostingController = hostingController {
            hostingController.rootView = contentView
        } else {
            let controller = UIHostingController(rootView: contentView)
            addChild(controller)
            controller.view.frame = self.view.bounds
            controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.addSubview(controller.view)
            controller.didMove(toParent: self)
            hostingController = controller
        }
    }

    private func processSharedContent() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            showError("No content to share")
            return
        }

        Task {
            await processAttachments(attachments)
        }
    }

    private func processAttachments(_ attachments: [NSItemProvider]) async {
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                do {
                    let url = try await loadURL(from: attachment)
                    try await feedlyService.sendToFeedly(url: url)
                    await MainActor.run {
                        showStatus(.success)
                        // Auto-dismiss after success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            self?.dismissExtension()
                        }
                    }
                    return
                } catch let error as FeedlyServiceError {
                    await MainActor.run { showError(error.localizedDescription) }
                    return
                } catch {
                    await MainActor.run { showError("Failed to send: \(error.localizedDescription)") }
                    return
                }
            }
        }

        await MainActor.run { showError("No URL found in shared content") }
    }

    private func loadURL(from attachment: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: FeedlyServiceError.invalidURL)
                }
            }
        }
    }

    private func showError(_ message: String) {
        showStatus(.error(message))
    }

    private func dismissExtension() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
