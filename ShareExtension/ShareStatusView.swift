import LifegamesTokens
import SwiftUI

// MARK: - ShareStatus

/// The three states the share sheet presents while submitting a URL.
///
/// Split out of `ShareExtensionView` so each state can be rendered and asserted
/// without standing up an `NSExtensionContext`. The extension host cannot be
/// created in a unit test, so keeping the state machine in the container view
/// left the share sheet's only visual states unrenderable and untested.
enum ShareStatus: Equatable {
  case progress
  case success
  case failure(String)
}

extension ShareStatus {
  /// The design-system token that tints the state's indicator (S21).
  var accent: Color {
    switch self {
    case .progress: LGColor.accentBlue
    case .success: LGColor.accentGreen
    case .failure: LGColor.accentRed
    }
  }

  /// The copy shown under the indicator.
  var message: String {
    switch self {
    case .progress: "Sending to Downloader..."
    case .success: "Sent to Downloader"
    case let .failure(message): message
    }
  }

  /// SF Symbol for the state, or `nil` while the spinner stands in for an icon.
  var iconSystemName: String? {
    switch self {
    case .progress: nil
    case .success: "checkmark.circle.fill"
    case .failure: "exclamationmark.triangle.fill"
    }
  }

  /// Only a failure needs a manual dismiss; the other states resolve on their own.
  var isDismissable: Bool {
    if case .failure = self {
      return true
    }
    return false
  }
}

// MARK: - ShareStatusView

/// Renders one `ShareStatus` on the share sheet card. Holds no state and runs
/// no effects, so a preview or a snapshot test can render any state directly.
struct ShareStatusView: View {
  let status: ShareStatus
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      LGColor.surfaceBase
        .ignoresSafeArea()

      VStack(spacing: 24) {
        switch status {
        case .progress:
          progressView

        case .success:
          successView

        case let .failure(message):
          failureView(message: message)
        }
      }
      .padding(32)
      .background(LGColor.surfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .padding(.horizontal, 32)
    }
  }

  // MARK: - State Views

  private var progressView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(status.accent)
        .scaleEffect(1.5)

      Text(status.message)
        .font(.body)
        .foregroundStyle(LGColor.textSubtle)
    }
  }

  private var successView: some View {
    VStack(spacing: 16) {
      Image(systemName: status.iconSystemName ?? "")
        .font(.system(size: 48))
        .foregroundStyle(status.accent)

      Text(status.message)
        .font(.headline)
        .foregroundStyle(.white)
    }
  }

  private func failureView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: status.iconSystemName ?? "")
        .font(.system(size: 48))
        .foregroundStyle(status.accent)

      Text(message)
        .font(.body)
        .foregroundStyle(LGColor.textSubtle)
        .multilineTextAlignment(.center)

      Button("Dismiss") {
        onDismiss()
      }
      .font(.body.weight(.semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(LGColor.accentBlue)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }
}

// MARK: - Previews

#Preview("Progress") {
  ShareStatusView(status: .progress, onDismiss: {})
    .preferredColorScheme(.dark)
}

#Preview("Success") {
  ShareStatusView(status: .success, onDismiss: {})
    .preferredColorScheme(.dark)
}

#Preview("Failure") {
  ShareStatusView(
    status: .failure("No valid YouTube URL found in shared content."),
    onDismiss: {}
  )
  .preferredColorScheme(.dark)
}
