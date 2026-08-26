import LifegamesTokens
import SwiftUI

// MARK: - ShareExtensionView

struct ShareExtensionView: View {
  let extensionContext: NSExtensionContext?
  let onComplete: () -> Void
  let onCancel: () -> Void

  @State private var viewState: ViewState = .loading

  private enum ViewState {
    case loading
    case success
    case error(String)
  }

  var body: some View {
    ZStack {
      LGColor.surfaceBase
        .ignoresSafeArea()

      VStack(spacing: 24) {
        switch viewState {
        case .loading:
          loadingView

        case .success:
          successView

        case let .error(message):
          errorView(message: message)
        }
      }
      .padding(32)
      .background(LGColor.surfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .padding(.horizontal, 32)
    }
    .task {
      await handleShare()
    }
  }

  // MARK: - State Views

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(LGColor.accentBlue)
        .scaleEffect(1.5)

      Text("Sending to Downloader...")
        .font(.body)
        .foregroundStyle(LGColor.textSubtle)
    }
  }

  private var successView: some View {
    VStack(spacing: 16) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundStyle(LGColor.accentGreen)

      Text("Sent to Downloader")
        .font(.headline)
        .foregroundStyle(.white)
    }
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundStyle(LGColor.accentRed)

      Text(message)
        .font(.body)
        .foregroundStyle(LGColor.textSubtle)
        .multilineTextAlignment(.center)

      Button("Dismiss") {
        onCancel()
      }
      .font(.body.weight(.semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(LGColor.accentBlue)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }

  // MARK: - Share Handling

  private func handleShare() async {
    guard let url = await ShareViewController.extractURL(from: extensionContext) else {
      viewState = .error("No valid YouTube URL found in shared content.")
      return
    }

    do {
      try await ShareService.submitURL(url)
      viewState = .success
      try? await Task.sleep(for: .seconds(1.5))
      onComplete()
    } catch {
      viewState = .error(error.localizedDescription)
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
