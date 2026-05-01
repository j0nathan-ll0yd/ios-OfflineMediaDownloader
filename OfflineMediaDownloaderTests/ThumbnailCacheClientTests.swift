import ComposableArchitecture
import Foundation
import Testing
@testable import ThumbnailCacheClient

struct ThumbnailCacheClientTests {
  // MARK: - Test Value Tests

  @Test("testValue returns nil for getThumbnail")
  func valueGetThumbnail() async throws {
    let client = ThumbnailCacheClient.testValue
    let result = try await client.getThumbnail("test-id", #require(URL(string: "https://example.com/thumb.jpg")))
    #expect(result == nil)
  }

  @Test("testValue returns false for hasCachedThumbnail")
  func valueHasCached() async {
    let client = ThumbnailCacheClient.testValue
    let result = await client.hasCachedThumbnail("test-id")
    #expect(result == false)
  }

  @Test("testValue deleteThumbnail does not throw")
  func valueDelete() async {
    let client = ThumbnailCacheClient.testValue
    await client.deleteThumbnail("test-id")
    // No exception = pass
  }

  @Test("testValue clearCache does not throw")
  func valueClear() async {
    let client = ThumbnailCacheClient.testValue
    await client.clearCache()
    // No exception = pass
  }

  // MARK: - Preview Value Tests

  @Test("previewValue returns nil for getThumbnail")
  func previewValueGetThumbnail() async throws {
    let client = ThumbnailCacheClient.previewValue
    let result = try await client.getThumbnail("test-id", #require(URL(string: "https://example.com/thumb.jpg")))
    #expect(result == nil)
  }

  // MARK: - Dependency Integration Tests

  @MainActor
  @Test("ThumbnailCacheClient is injectable via dependency")
  func dependencyInjectable() async {
    let wasCalled = LockIsolated(false)

    await withDependencies {
      $0.thumbnailCacheClient.deleteThumbnail = { _ in
        wasCalled.setValue(true)
      }
    } operation: {
      @Dependency(\.thumbnailCacheClient) var client
      await client.deleteThumbnail("test-id")
    }

    #expect(wasCalled.value == true)
  }
}
