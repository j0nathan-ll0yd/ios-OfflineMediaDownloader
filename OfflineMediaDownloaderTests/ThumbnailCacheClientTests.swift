import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("ThumbnailCacheClient Tests")
struct ThumbnailCacheClientTests {

  // MARK: - Test Value Tests

  @Test("testValue returns nil for getThumbnail")
  func testValueGetThumbnail() async throws {
    let client = ThumbnailCacheClient.testValue
    let result = await client.getThumbnail("test-id", URL(string: "https://example.com/thumb.jpg")!)
    #expect(result == nil)
  }

  @Test("testValue returns false for hasCachedThumbnail")
  func testValueHasCached() async throws {
    let client = ThumbnailCacheClient.testValue
    let result = client.hasCachedThumbnail("test-id")
    #expect(result == false)
  }

  @Test("testValue deleteThumbnail does not throw")
  func testValueDelete() async throws {
    let client = ThumbnailCacheClient.testValue
    await client.deleteThumbnail("test-id")
    // No exception = pass
  }

  @Test("testValue clearCache does not throw")
  func testValueClear() async throws {
    let client = ThumbnailCacheClient.testValue
    await client.clearCache()
    // No exception = pass
  }

  // MARK: - Preview Value Tests

  @Test("previewValue returns nil for getThumbnail")
  func previewValueGetThumbnail() async throws {
    let client = ThumbnailCacheClient.previewValue
    let result = await client.getThumbnail("test-id", URL(string: "https://example.com/thumb.jpg")!)
    #expect(result == nil)
  }

  // MARK: - Dependency Integration Tests

  @MainActor
  @Test("ThumbnailCacheClient is injectable via dependency")
  func dependencyInjectable() async throws {
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
