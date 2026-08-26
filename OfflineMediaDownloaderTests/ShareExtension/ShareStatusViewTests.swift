import Foundation
@testable import OfflineMediaDownloader
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Acceptance coverage for the share sheet's three visual states after the S21
/// remediation swapped the forked iOS system palette for design-system tokens.
///
/// Two layers, on purpose. The snapshots are the inspected render attached to
/// the PR. The behavioral assertions below them do not depend on a screenshot,
/// so a regression is caught even when nobody re-inspects a baseline: they pin
/// the state-to-token wiring, the copy, the dismiss affordance, and the fact
/// that the tokens actually resolve out of the `LifegamesTokens` resource
/// bundle instead of falling back to clear.
@MainActor
struct ShareStatusViewTests {
  // MARK: - Helpers

  /// Resolves a SwiftUI `Color` through UIKit so an asset-catalog token yields
  /// concrete components. A token whose resource bundle is missing resolves to
  /// fully transparent black, which every assertion here rejects.
  private func resolve(_ color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue, alpha)
  }

  /// `#RRGGBB` for a resolved token, ignoring alpha.
  private func hex(_ color: Color) -> String {
    let components = resolve(color)
    return String(
      format: "#%02X%02X%02X",
      Int((components.red * 255).rounded()),
      Int((components.green * 255).rounded()),
      Int((components.blue * 255).rounded())
    )
  }

  private func makeView(status: ShareStatus) -> some View {
    ShareStatusView(status: status, onDismiss: {})
      .preferredColorScheme(.dark)
  }

  // MARK: - Inspected Renders

  @Test("ShareStatusView snapshot - progress")
  func snapshotProgress() {
    assertSnapshot(
      of: makeView(status: .progress),
      as: .image(layout: .fixed(width: 390, height: 300)),
      named: "progress"
    )
  }

  @Test("ShareStatusView snapshot - success")
  func snapshotSuccess() {
    assertSnapshot(
      of: makeView(status: .success),
      as: .image(layout: .fixed(width: 390, height: 300)),
      named: "success"
    )
  }

  @Test("ShareStatusView snapshot - error")
  func snapshotError() {
    assertSnapshot(
      of: makeView(status: .failure("No valid YouTube URL found in shared content.")),
      as: .image(layout: .fixed(width: 390, height: 300)),
      named: "error"
    )
  }

  // MARK: - Behavioral: State Presentation

  @Test("Progress state shows the spinner copy and no icon")
  func progressPresentation() {
    let status = ShareStatus.progress
    #expect(status.message == "Sending to Downloader...")
    #expect(status.iconSystemName == nil)
    #expect(status.isDismissable == false)
  }

  @Test("Success state shows the checkmark icon and confirmation copy")
  func successPresentation() {
    let status = ShareStatus.success
    #expect(status.message == "Sent to Downloader")
    #expect(status.iconSystemName == "checkmark.circle.fill")
    #expect(status.isDismissable == false)
  }

  @Test("Error state surfaces the failure text and a dismiss affordance")
  func errorPresentation() {
    let status = ShareStatus.failure("No valid YouTube URL found in shared content.")
    #expect(status.message == "No valid YouTube URL found in shared content.")
    #expect(status.iconSystemName == "exclamationmark.triangle.fill")
    #expect(status.isDismissable)
  }

  // MARK: - Behavioral: Token Resolution

  // `LGColor` reads `Bundle.module`, which inside an `.appex` resolves against
  // the extension bundle. If `LifegamesDesignSystem_LifegamesTokens.bundle` is
  // not embedded, every token silently resolves to clear and the share sheet
  // renders as a black rectangle instead of failing the build. These assertions
  // turn that runtime condition into a test failure.

  @Test("Every state accent resolves opaque out of the tokens bundle")
  func accentsResolveFromBundle() {
    for status in [ShareStatus.progress, .success, .failure("boom")] {
      let components = resolve(status.accent)
      #expect(components.alpha == 1.0, "\(status) accent did not resolve from the tokens bundle")
    }
  }

  @Test("Each state maps to a distinct design-system accent token")
  func accentsAreDistinctPerState() {
    let accents = [ShareStatus.progress, .success, .failure("boom")].map { hex($0.accent) }
    #expect(Set(accents).count == 3, "states share an accent: \(accents)")
  }

  /// Pins the palette this PR moved to. The old values were the iOS system
  /// palette (`#007AFF`, `#34C759`, `#FF453A`); these are the Lifegames tokens.
  /// Source of truth: design-system-Lifegames
  /// `Sources/LifegamesTokens/Resources/Colors.xcassets/color-accent-*.colorset`.
  /// A change here means the share sheet's rendered colors changed and the PR
  /// renders need re-inspecting.
  @Test("Accents are the Lifegames palette, not the iOS system palette")
  func accentsAreDesignSystemPalette() {
    #expect(hex(ShareStatus.progress.accent) == "#3A86FF")
    #expect(hex(ShareStatus.success.accent) == "#06D6A0")
    #expect(hex(ShareStatus.failure("boom").accent) == "#EF4444")

    #expect(hex(ShareStatus.progress.accent) != "#007AFF")
    #expect(hex(ShareStatus.success.accent) != "#34C759")
    #expect(hex(ShareStatus.failure("boom").accent) != "#FF453A")
  }
}
