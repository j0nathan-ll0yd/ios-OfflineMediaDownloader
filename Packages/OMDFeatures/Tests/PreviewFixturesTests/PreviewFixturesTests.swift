import Foundation
@testable import PreviewFixtures
import Testing

/// Executes every PreviewFixtures accessor. The accessors decode design-system
/// fixture JSON (media/*.json) and `preconditionFailure` on any mismatch —
/// previews fail loudly. This suite makes that failure surface in CI instead
/// of at preview-render time (S98).
@MainActor
@Suite("PreviewFixtures — every fixture accessor decodes")
struct PreviewFixturesTests {
  @Test(arguments: [
    PreviewFixtures.FileVariant.downloaded, .pending, .longMetadata,
  ])
  func fileDecodes(_ variant: PreviewFixtures.FileVariant) {
    let file = PreviewFixtures.file(variant)
    #expect(!file.fileId.isEmpty)
    #expect(!file.key.isEmpty)
  }

  @Test func downloadedFileMapsWireFields() throws {
    let file = PreviewFixtures.file(.downloaded)
    #expect(file.title == "SwiftUI State Management Deep Dive")
    #expect(file.size == 1_258_291_200)
    #expect(file.duration == 6138)
    #expect(file.status == .downloaded)
    #expect(file.url != nil)
    // publishDate "20250112" parses via DateFormatters (YYYYMMDD).
    let date = try #require(file.publishDate)
    #expect(Calendar.current.component(.year, from: date) == 2025)
  }

  @Test(arguments: [
    PreviewFixtures.LibraryVariant.populatedMax, .populatedMin, .empty,
  ])
  func filesDecode(_ variant: PreviewFixtures.LibraryVariant) {
    let files = PreviewFixtures.files(variant)
    switch variant {
    case .populatedMax: #expect(files.count == 8)
    case .populatedMin: #expect(files.count == 1)
    case .empty: #expect(files.isEmpty)
    }
  }

  @Test func libraryCoversAllStatuses() {
    let statuses = Set(PreviewFixtures.files(.populatedMax).compactMap(\.status))
    #expect(statuses.isSuperset(of: [.pending, .queued, .downloading, .downloaded, .failed]))
  }

  @Test(arguments: [
    PreviewFixtures.ProfileVariant.standard, .newUser,
  ])
  func userAndMetricsDecode(_ variant: PreviewFixtures.ProfileVariant) {
    let user = PreviewFixtures.user(variant)
    #expect(user.email.contains("@"))
    let metrics = PreviewFixtures.fileMetrics(variant)
    #expect(metrics.downloadCount >= 0)
  }

  @Test func standardProfileValues() {
    let user = PreviewFixtures.user(.standard)
    #expect(user.firstName == "Sample")
    let metrics = PreviewFixtures.fileMetrics(.standard)
    #expect(metrics.downloadCount == 12)
    #expect(metrics.totalStorageBytes == 2_400_000_000)
  }
}
