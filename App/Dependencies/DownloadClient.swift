import ComposableArchitecture
import Foundation

enum DownloadProgress: Equatable, Sendable {
  case progress(percent: Int)
  case completed(localURL: URL)
  case failed(String)
}

@DependencyClient
struct DownloadClient {
  var downloadFile: @Sendable (_ url: URL, _ expectedSize: Int64) -> AsyncStream<DownloadProgress> = { _, _ in
    AsyncStream { _ in }
  }
  var cancelDownload: @Sendable (_ url: URL) async -> Void
}

extension DependencyValues {
  var downloadClient: DownloadClient {
    get { self[DownloadClient.self] }
    set { self[DownloadClient.self] = newValue }
  }
}

// MARK: - Download Manager (handles URLSession delegate)
actor DownloadManager: NSObject {
  static let shared = DownloadManager()

  private var activeTasks: [URL: URLSessionDownloadTask] = [:]
  private var progressContinuations: [URL: AsyncStream<DownloadProgress>.Continuation] = [:]
  private var progressObservations: [URL: NSKeyValueObservation] = [:]
  private var backgroundCompletionHandler: (() -> Void)?

  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "com.offlinemediadownloader.background")
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.timeoutIntervalForRequest = 180
    config.requestCachePolicy = .returnCacheDataElseLoad
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  func downloadFile(url: URL, expectedSize: Int64) -> AsyncStream<DownloadProgress> {
    AsyncStream { continuation in
      Task {
        await self.startDownload(url: url, expectedSize: expectedSize, continuation: continuation)
      }
    }
  }

  private func startDownload(url: URL, expectedSize: Int64, continuation: AsyncStream<DownloadProgress>.Continuation) async {
    // Cancel any existing download for this URL
    if let existingTask = activeTasks[url] {
      existingTask.cancel()
      progressObservations[url]?.invalidate()
    }

    progressContinuations[url] = continuation

    let task = session.downloadTask(with: url)
    task.countOfBytesClientExpectsToReceive = expectedSize
    activeTasks[url] = task

    // Observe progress
    let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
      let percent = Int(progress.fractionCompleted * 100)
      Task {
        await self?.sendProgress(for: url, percent: percent)
      }
    }
    progressObservations[url] = observation

    task.resume()

    continuation.onTermination = { [weak self] _ in
      Task {
        await self?.cancelDownload(url: url)
      }
    }
  }

  private func sendProgress(for url: URL, percent: Int) {
    progressContinuations[url]?.yield(.progress(percent: percent))
  }

  func cancelDownload(url: URL) {
    activeTasks[url]?.cancel()
    activeTasks[url] = nil
    progressObservations[url]?.invalidate()
    progressObservations[url] = nil
    progressContinuations[url]?.finish()
    progressContinuations[url] = nil
  }

  func handleDownloadSuccess(for url: URL, localURL: URL) {
    progressContinuations[url]?.yield(.completed(localURL: localURL))
    cleanup(for: url)
  }

  func handleDownloadError(for url: URL, error: Error) {
    progressContinuations[url]?.yield(.failed(error.localizedDescription))
    cleanup(for: url)
  }

  private func cleanup(for url: URL) {
    activeTasks[url] = nil
    progressObservations[url]?.invalidate()
    progressObservations[url] = nil
    progressContinuations[url]?.finish()
    progressContinuations[url] = nil
  }

  // MARK: - Background Session Support

  func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
    self.backgroundCompletionHandler = handler
  }

  private func callCompletionHandler() {
    backgroundCompletionHandler?()
    backgroundCompletionHandler = nil
  }
}

// MARK: - URLSession Delegate
extension DownloadManager: URLSessionDownloadDelegate, URLSessionDelegate {
  // MARK: Authentication Challenge (Certificate Pinning)
  nonisolated func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    // Only handle server trust challenges
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
          let serverTrust = challenge.protectionSpace.serverTrust else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    // First, perform standard trust evaluation
    var error: CFError?
    let trustValid = SecTrustEvaluateWithError(serverTrust, &error)

    guard trustValid else {
      print("📥 Certificate validation failed: \(error?.localizedDescription ?? "Unknown error")")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    // Then, validate our certificate pins
    let pinValid = CertificatePinning.validate(serverTrust: serverTrust)

    if pinValid {
      print("📥 Certificate pinning validated for download")
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    } else {
      print("📥 Certificate pinning failed - download connection rejected")
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }

  // MARK: Download Completion
  nonisolated func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let originalURL = downloadTask.originalRequest?.url else { return }

    // CRITICAL: Must move file synchronously before this callback returns!
    // The temp file is deleted immediately after this method returns.
    let fileManager = FileManager.default
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let destinationURL = documentsPath.appendingPathComponent(originalURL.lastPathComponent)

    print("📥 Download complete, moving file:")
    print("   From: \(location.path)")
    print("   To: \(destinationURL.path)")

    do {
      // Remove existing file if present
      if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
      }
      try fileManager.moveItem(at: location, to: destinationURL)
      print("📥 File moved successfully")

      Task {
        await self.handleDownloadSuccess(for: originalURL, localURL: destinationURL)
      }
    } catch {
      print("📥 File move failed: \(error)")
      Task {
        await self.handleDownloadError(for: originalURL, error: error)
      }
    }
  }

  nonisolated func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let error = error,
          let originalURL = task.originalRequest?.url else { return }

    Task {
      await self.handleDownloadError(for: originalURL, error: error)
    }
  }

  nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    print("📥 URLSession background events finished")
    Task {
      await self.callCompletionHandler()
    }
  }
}

// MARK: - Live API implementation
extension DownloadClient: DependencyKey {
  static let liveValue = DownloadClient(
    downloadFile: { url, expectedSize in
      AsyncStream { continuation in
        Task {
          let stream = await DownloadManager.shared.downloadFile(url: url, expectedSize: expectedSize)
          for await progress in stream {
            continuation.yield(progress)
          }
          continuation.finish()
        }
      }
    },
    cancelDownload: { url in
      await DownloadManager.shared.cancelDownload(url: url)
    }
  )
}

// MARK: - Test implementation
extension DownloadClient {
  static let testValue = DownloadClient(
    downloadFile: { _, _ in
      AsyncStream { continuation in
        continuation.yield(.progress(percent: 50))
        continuation.yield(.progress(percent: 100))
        continuation.yield(.completed(localURL: URL(fileURLWithPath: "/tmp/test.mp4")))
        continuation.finish()
      }
    },
    cancelDownload: { _ in }
  )
}
