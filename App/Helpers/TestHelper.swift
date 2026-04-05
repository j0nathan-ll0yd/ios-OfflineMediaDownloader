import Foundation

enum TestHelper {
  static func getDefaultFile() -> File {
    File(
      fileId: "test-file-123",
      key: "Test Video.mp4",
      publishDate: Date(),
      size: 1_024_000,
      url: URL(string: "https://example.com/test.mp4")
    )
  }
}
