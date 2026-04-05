import ComposableArchitecture
import Foundation
@testable import OfflineMediaDownloader
import Testing

// MARK: - Mock URLProtocol for Testing

/// A URLProtocol subclass that allows us to mock network responses in tests
final class MockURLProtocol: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
  nonisolated(unsafe) static var progressHandler: ((URLRequest, @escaping (Int64, Int64) -> Void) -> Void)?

  override class func canInit(with _: URLRequest) -> Bool {
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let handler = MockURLProtocol.requestHandler else {
      fatalError("MockURLProtocol.requestHandler is not set")
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      if let data = data {
        client?.urlProtocol(self, didLoad: data)
      }
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

// MARK: - Test Errors

enum MockDownloadError: Error {
  case networkFailure
  case invalidURL
  case cancelled
}

struct DownloadClientTests {
  // MARK: - DownloadProgress Enum Tests

  @Test("DownloadProgress.progress stores correct percent")
  func downloadProgressPercent() {
    let progress = DownloadProgress.progress(percent: 50)
    if case let .progress(percent) = progress {
      #expect(percent == 50)
    } else {
      Issue.record("Expected progress case")
    }
  }

  @Test("DownloadProgress.completed stores correct URL")
  func downloadProgressCompleted() {
    let url = URL(fileURLWithPath: "/tmp/test.mp4")
    let progress = DownloadProgress.completed(localURL: url)
    if case let .completed(localURL) = progress {
      #expect(localURL == url)
    } else {
      Issue.record("Expected completed case")
    }
  }

  @Test("DownloadProgress.failed stores error message")
  func downloadProgressFailed() {
    let progress = DownloadProgress.failed("Network error")
    if case let .failed(message) = progress {
      #expect(message == "Network error")
    } else {
      Issue.record("Expected failed case")
    }
  }

  @Test("DownloadProgress values are Equatable")
  func downloadProgressEquatable() {
    let progress1 = DownloadProgress.progress(percent: 50)
    let progress2 = DownloadProgress.progress(percent: 50)
    let progress3 = DownloadProgress.progress(percent: 75)

    #expect(progress1 == progress2)
    #expect(progress1 != progress3)

    let url = URL(fileURLWithPath: "/tmp/test.mp4")
    let completed1 = DownloadProgress.completed(localURL: url)
    let completed2 = DownloadProgress.completed(localURL: url)
    #expect(completed1 == completed2)

    let failed1 = DownloadProgress.failed("error")
    let failed2 = DownloadProgress.failed("error")
    #expect(failed1 == failed2)
  }

  // MARK: - DownloadClient testValue Tests

  @Test("DownloadClient testValue emits expected progress sequence")
  func valueProgressSequence() async throws {
    let client = DownloadClient.testValue
    let url = try #require(URL(string: "https://example.com/video.mp4"))

    var progressValues: [DownloadProgress] = []
    for await progress in client.downloadFile(url, 1000) {
      progressValues.append(progress)
    }

    #expect(progressValues.count == 3)

    // Check first progress (50%)
    if case let .progress(percent) = progressValues[0] {
      #expect(percent == 50)
    } else {
      Issue.record("Expected progress at index 0")
    }

    // Check second progress (100%)
    if case let .progress(percent) = progressValues[1] {
      #expect(percent == 100)
    } else {
      Issue.record("Expected progress at index 1")
    }

    // Check completed
    if case let .completed(localURL) = progressValues[2] {
      #expect(localURL.path == "/tmp/test.mp4")
    } else {
      Issue.record("Expected completed at index 2")
    }
  }

  @Test("DownloadClient testValue cancelDownload does not throw")
  func valueCancelDownload() async throws {
    let client = DownloadClient.testValue
    let url = try #require(URL(string: "https://example.com/video.mp4"))

    // Should complete without error
    await client.cancelDownload(url)
  }

  // MARK: - DownloadClient liveValue Configuration Tests

  @Test("DownloadClient liveValue is configured correctly")
  func liveValueConfiguration() {
    let client = DownloadClient.liveValue

    // Verify the client has both functions configured
    let downloadFile = client.downloadFile
    let cancelDownload = client.cancelDownload

    // Type checks - these will fail at compile time if types are wrong
    _ = downloadFile as @Sendable (URL, Int64) -> AsyncStream<DownloadProgress>
    _ = cancelDownload as @Sendable (URL) async -> Void

    // No runtime assertion needed - type system verifies
  }

  // MARK: - Custom Mock Client Tests

  @Test("Custom mock client can simulate failure")
  func customMockClientFailure() async throws {
    let mockClient = DownloadClient(
      downloadFile: { _, _ in
        AsyncStream { continuation in
          continuation.yield(.progress(percent: 10))
          continuation.yield(.failed("Connection lost"))
          continuation.finish()
        }
      },
      cancelDownload: { _ in }
    )

    let url = try #require(URL(string: "https://example.com/video.mp4"))
    var progressValues: [DownloadProgress] = []

    for await progress in mockClient.downloadFile(url, 1000) {
      progressValues.append(progress)
    }

    #expect(progressValues.count == 2)

    if case let .failed(message) = progressValues[1] {
      #expect(message == "Connection lost")
    } else {
      Issue.record("Expected failed case")
    }
  }

  @Test("Custom mock client can simulate slow progress")
  func customMockClientSlowProgress() async throws {
    let mockClient = DownloadClient(
      downloadFile: { _, _ in
        AsyncStream { continuation in
          for percent in stride(from: 0, through: 100, by: 25) {
            continuation.yield(.progress(percent: percent))
          }
          continuation.yield(.completed(localURL: URL(fileURLWithPath: "/downloaded.mp4")))
          continuation.finish()
        }
      },
      cancelDownload: { _ in }
    )

    let url = try #require(URL(string: "https://example.com/video.mp4"))
    var progressValues: [DownloadProgress] = []

    for await progress in mockClient.downloadFile(url, 1000) {
      progressValues.append(progress)
    }

    #expect(progressValues.count == 6) // 0, 25, 50, 75, 100, completed
  }

  // MARK: - Integration with TCA Dependency System

  @MainActor
  @Test("DownloadClient can be injected as dependency")
  func dependencyInjection() async {
    nonisolated(unsafe) var capturedURL: URL?
    nonisolated(unsafe) var capturedSize: Int64?

    let testClient = DownloadClient(
      downloadFile: { url, size in
        capturedURL = url
        capturedSize = size
        return AsyncStream { continuation in
          continuation.yield(.completed(localURL: URL(fileURLWithPath: "/test.mp4")))
          continuation.finish()
        }
      },
      cancelDownload: { _ in }
    )

    await withDependencies {
      $0.downloadClient = testClient
    } operation: {
      @Dependency(\.downloadClient) var downloadClient

      let url = URL(string: "https://example.com/video.mp4")!
      for await _ in downloadClient.downloadFile(url, 5000) {}

      #expect(capturedURL?.absoluteString == "https://example.com/video.mp4")
      #expect(capturedSize == 5000)
    }
  }
}

// MARK: - URLProtocol Based Integration Tests

// Note: These tests use .serialized to ensure they run sequentially,
// avoiding conflicts with URLProtocol's static handler pattern.

@Suite(.serialized)
struct DownloadManagerIntegrationTests {
  @Test("MockURLProtocol can intercept requests")
  func mockURLProtocolIntercepts() async throws {
    defer {
      MockURLProtocol.requestHandler = nil
      MockURLProtocol.progressHandler = nil
    }

    // Configure mock handler
    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data("test content".utf8))
    }

    // Create a session with mock protocol
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    // Make request
    let url = try #require(URL(string: "https://example.com/test.mp4"))
    let (data, response) = try await session.data(from: url)

    // Verify
    let httpResponse = try #require(response as? HTTPURLResponse)
    #expect(httpResponse.statusCode == 200)
    #expect(String(data: data, encoding: .utf8) == "test content")
  }

  @Test("MockURLProtocol can simulate errors")
  func mockURLProtocolSimulatesError() async throws {
    defer {
      MockURLProtocol.requestHandler = nil
      MockURLProtocol.progressHandler = nil
    }

    // Configure mock to return error
    MockURLProtocol.requestHandler = { _ in
      throw MockDownloadError.networkFailure
    }

    // Create a session with mock protocol
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    // Make request and expect error
    let url = try #require(URL(string: "https://example.com/test.mp4"))
    do {
      _ = try await session.data(from: url)
      Issue.record("Expected error to be thrown")
    } catch {
      // URLSession wraps errors from URLProtocol in various ways depending on iOS version.
      // We just need to verify an error was thrown - the specific wrapping is an
      // implementation detail that varies across iOS versions.
      #expect(true, "Error was thrown as expected: \(error)")
    }
  }
}
