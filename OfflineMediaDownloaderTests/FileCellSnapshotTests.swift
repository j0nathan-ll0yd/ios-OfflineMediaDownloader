import Foundation
import Testing
import ComposableArchitecture
import SwiftUI
import SnapshotTesting
@testable import OfflineMediaDownloader

@Suite("FileCellView Snapshot Tests")
struct FileCellSnapshotTests {

  // MARK: - Test Helpers

  /// Creates a test file with the given properties
  private func makeTestFile(
    id: String = "test-file-id",
    title: String = "Test Video Title",
    author: String? = "Test Author",
    size: Int? = 45_000_000,  // 45 MB
    publishDate: Date? = Date().addingTimeInterval(-86400),  // 1 day ago
    url: URL? = URL(string: "https://example.com/video.mp4")
  ) -> File {
    var file = File(
      fileId: id,
      key: "test-key.mp4",
      publishDate: publishDate,
      size: size,
      url: url
    )
    file.title = title
    file.authorName = author
    return file
  }

  /// Creates a FileCellFeature.State with the given file and download state
  private func makeState(
    file: File,
    isDownloading: Bool = false,
    downloadProgress: Double = 0,
    isDownloaded: Bool = false
  ) -> FileCellFeature.State {
    var state = FileCellFeature.State(file: file)
    state.isDownloading = isDownloading
    state.downloadProgress = downloadProgress
    state.isDownloaded = isDownloaded
    return state
  }

  /// Creates a FileCellView with the given state
  @MainActor
  private func makeView(state: FileCellFeature.State) -> FileCellView {
    let store = Store(initialState: state) {
      FileCellFeature()
    } withDependencies: {
      $0.serverClient = .testValue
      $0.coreDataClient = .testValue
      $0.fileClient = .testValue
      $0.downloadClient = .testValue
      $0.logger = .testValue
    }
    return FileCellView(store: store)
  }

  // MARK: - Ready to Download State

  @MainActor
  @Test("FileCellView snapshot - ready to download")
  func snapshotReadyToDownload() async {
    let file = makeTestFile()
    let state = makeState(file: file, isDownloaded: false)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "ready_to_download"
    )
  }

  @MainActor
  @Test("FileCellView snapshot - ready to download (dark mode)")
  func snapshotReadyToDownloadDarkMode() async {
    let file = makeTestFile()
    let state = makeState(file: file, isDownloaded: false)
    let view = makeView(state: state)
      .preferredColorScheme(.dark)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "ready_to_download_dark"
    )
  }

  // MARK: - Downloading State

  @MainActor
  @Test("FileCellView snapshot - downloading 25%")
  func snapshotDownloading25() async {
    let file = makeTestFile()
    let state = makeState(file: file, isDownloading: true, downloadProgress: 0.25)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "downloading_25"
    )
  }

  @MainActor
  @Test("FileCellView snapshot - downloading 75%")
  func snapshotDownloading75() async {
    let file = makeTestFile()
    let state = makeState(file: file, isDownloading: true, downloadProgress: 0.75)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "downloading_75"
    )
  }

  // MARK: - Downloaded State

  @MainActor
  @Test("FileCellView snapshot - downloaded (ready to play)")
  func snapshotDownloaded() async {
    let file = makeTestFile()
    let state = makeState(file: file, isDownloaded: true)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "downloaded"
    )
  }

  // MARK: - Pending State

  @MainActor
  @Test("FileCellView snapshot - pending (no URL)")
  func snapshotPending() async {
    let file = makeTestFile(url: nil)  // No URL = pending
    let state = makeState(file: file)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "pending"
    )
  }

  // MARK: - Edge Cases

  @MainActor
  @Test("FileCellView snapshot - long title (truncation)")
  func snapshotLongTitle() async {
    let file = makeTestFile(
      title: "This is a very long video title that should be truncated after two lines of text to prevent overflow"
    )
    let state = makeState(file: file, isDownloaded: false)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "long_title"
    )
  }

  @MainActor
  @Test("FileCellView snapshot - no author")
  func snapshotNoAuthor() async {
    let file = makeTestFile(author: nil)
    let state = makeState(file: file, isDownloaded: false)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "no_author"
    )
  }

  @MainActor
  @Test("FileCellView snapshot - large file size")
  func snapshotLargeFileSize() async {
    let file = makeTestFile(size: 2_500_000_000)  // 2.5 GB
    let state = makeState(file: file, isDownloaded: false)
    let view = makeView(state: state)

    assertSnapshot(
      of: view,
      as: .image(layout: .fixed(width: 375, height: 100)),
      named: "large_file"
    )
  }
}
