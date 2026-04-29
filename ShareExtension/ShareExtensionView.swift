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
      Color(hex: "121212")
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
      .background(Color(hex: "1E1E1E"))
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
        .tint(Color(hex: "007AFF"))
        .scaleEffect(1.5)

      Text("Sending to Downloader...")
        .font(.body)
        .foregroundStyle(Color(hex: "8E8E93"))
    }
  }

  private var successView: some View {
    VStack(spacing: 16) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundStyle(Color(hex: "34C759"))

      Text("Sent to Downloader")
        .font(.headline)
        .foregroundStyle(.white)
    }
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundStyle(Color(hex: "FF453A"))

      Text(message)
        .font(.body)
        .foregroundStyle(Color(hex: "8E8E93"))
        .multilineTextAlignment(.center)

      Button("Dismiss") {
        onCancel()
      }
      .font(.body.weight(.semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(Color(hex: "007AFF"))
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

// MARK: - Color Hex Extension (private — extension cannot import main app Theme)

private extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255.0
    let g = Double((int >> 8) & 0xFF) / 255.0
    let b = Double(int & 0xFF) / 255.0
    self.init(red: r, green: g, blue: b)
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
