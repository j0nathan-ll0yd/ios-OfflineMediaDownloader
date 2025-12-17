# Background Downloads

## Quick Reference
- **When to use**: Downloading files that may take time
- **Enforcement**: Required for large files
- **Impact if violated**: High - Failed downloads, poor UX

---

## Overview

Downloads use a custom `DownloadClient` backed by a `DownloadManager` actor for thread-safe URLSession management.

---

## DownloadClient Interface

```swift
@DependencyClient
struct DownloadClient {
  var downloadFile: @Sendable (_ url: URL, _ expectedSize: Int64) -> AsyncStream<DownloadProgress>
  var cancelDownload: @Sendable (_ url: URL) async -> Void
}

enum DownloadProgress: Equatable, Sendable {
  case progress(percent: Int)
  case completed(localURL: URL)
  case failed(String)
}
```

---

## DownloadManager Actor

```swift
actor DownloadManager {
  static let shared = DownloadManager()

  private var activeTasks: [URL: URLSessionDownloadTask] = [:]
  private let session: URLSession

  init() {
    let config = URLSessionConfiguration.default
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.timeoutIntervalForRequest = 300
    self.session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
  }

  func download(_ url: URL, expectedSize: Int64) -> AsyncStream<DownloadProgress> {
    AsyncStream { continuation in
      Task {
        let task = session.downloadTask(with: url)
        activeTasks[url] = task

        // Observe progress via KVO
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
          let percent = Int(progress.fractionCompleted * 100)
          continuation.yield(.progress(percent: percent))
        }

        // Handle completion
        task.resume()

        // Wait for completion (simplified - real impl uses delegate)
        // ...

        continuation.onTermination = { @Sendable _ in
          observation.invalidate()
          Task { await self.cancel(url) }
        }
      }
    }
  }

  func cancel(_ url: URL) {
    if let task = activeTasks[url] {
      task.cancel()
      activeTasks[url] = nil
    }
  }
}
```

---

## Live Implementation

```swift
extension DownloadClient: DependencyKey {
  static let liveValue = DownloadClient(
    downloadFile: { url, expectedSize in
      DownloadManager.shared.download(url, expectedSize: expectedSize)
    },
    cancelDownload: { url in
      await DownloadManager.shared.cancel(url)
    }
  )
}
```

---

## Usage in FileCellFeature

### Starting Download
```swift
case .downloadButtonTapped:
  guard let remoteURL = state.file.url else { return .none }

  state.isDownloading = true
  state.downloadProgress = 0
  let expectedSize = Int64(state.file.size ?? 0)

  return .run { send in
    let stream = downloadClient.downloadFile(remoteURL, expectedSize)
    for await progress in stream {
      switch progress {
      case let .progress(percent):
        await send(.downloadProgressUpdated(Double(percent) / 100.0))
      case let .completed(localURL):
        await send(.downloadCompleted(localURL))
      case let .failed(message):
        await send(.downloadFailed(message))
      }
    }
  }
  .cancellable(id: CancelID.download, cancelInFlight: true)
```

### Updating Progress
```swift
case let .downloadProgressUpdated(progress):
  state.downloadProgress = progress
  return .none
```

### Handling Completion
```swift
case let .downloadCompleted(localURL):
  state.isDownloading = false
  state.downloadProgress = 1.0
  state.isDownloaded = true
  return .none
```

### Handling Failure
```swift
case let .downloadFailed(message):
  print("❌ Download failed: \(message)")
  state.isDownloading = false
  state.downloadProgress = 0
  return .none
```

### Cancellation
```swift
case .cancelDownloadButtonTapped:
  state.isDownloading = false
  state.downloadProgress = 0

  if let url = state.file.url {
    return .run { _ in
      await downloadClient.cancelDownload(url)
    }
    .merge(with: .cancel(id: CancelID.download))
  }
  return .cancel(id: CancelID.download)
```

---

## File Storage

### Documents Directory
```swift
let documentsURL = FileManager.default.urls(
  for: .documentDirectory,
  in: .userDomainMask
)[0]

let localPath = documentsURL.appendingPathComponent(remoteURL.lastPathComponent)
```

### Moving Downloaded File
```swift
// In URLSessionDownloadDelegate
func urlSession(
  _ session: URLSession,
  downloadTask: URLSessionDownloadTask,
  didFinishDownloadingTo location: URL
) {
  let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  let destinationURL = documentsURL.appendingPathComponent(downloadTask.originalRequest!.url!.lastPathComponent)

  // Remove existing file
  try? FileManager.default.removeItem(at: destinationURL)

  // Move temp file to documents
  try? FileManager.default.moveItem(at: location, to: destinationURL)
}
```

---

## Progress UI

### Circular Progress Indicator
```swift
ZStack {
  // Background circle
  Circle()
    .stroke(Color.white.opacity(0.3), lineWidth: 3)

  // Progress arc
  Circle()
    .trim(from: 0, to: store.downloadProgress)
    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
    .rotationEffect(.degrees(-90))

  // Cancel icon
  Image(systemName: "xmark")
    .font(.caption)
    .fontWeight(.bold)
    .foregroundColor(.white)
}
.frame(width: 36, height: 36)
```

### Text Progress
```swift
if store.isDownloading {
  Text("Downloading \(Int(store.downloadProgress * 100))% — Tap to cancel")
    .font(.caption2)
    .foregroundColor(.blue)
}
```

---

## Background Session Configuration

For true background downloads (app suspended):

```swift
let config = URLSessionConfiguration.background(withIdentifier: "com.yourapp.downloads")
config.isDiscretionary = false
config.sessionSendsLaunchEvents = true
config.allowsCellularAccess = true
```

### AppDelegate Handling
```swift
func application(
  _ application: UIApplication,
  handleEventsForBackgroundURLSession identifier: String,
  completionHandler: @escaping () -> Void
) {
  // Store completion handler
  backgroundCompletionHandler = completionHandler
}

// In URLSessionDelegate
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
  DispatchQueue.main.async {
    backgroundCompletionHandler?()
  }
}
```

---

## Testing

```swift
withDependencies: {
  // Successful download
  $0.downloadClient.downloadFile = { url, size in
    AsyncStream { continuation in
      continuation.yield(.progress(percent: 50))
      continuation.yield(.progress(percent: 100))
      continuation.yield(.completed(localURL: URL(fileURLWithPath: "/tmp/test.mp4")))
      continuation.finish()
    }
  }

  // Failed download
  $0.downloadClient.downloadFile = { _, _ in
    AsyncStream { continuation in
      continuation.yield(.failed("Network error"))
      continuation.finish()
    }
  }

  // Cancellation
  $0.downloadClient.cancelDownload = { url in
    print("Cancelled: \(url)")
  }
}
```

---

## Anti-Patterns

### Don't use synchronous downloads
```swift
// ❌ Wrong - Blocks thread
let data = try Data(contentsOf: url)

// ✅ Correct - Async streaming
for await progress in downloadClient.downloadFile(url, size) {
  // Handle progress
}
```

### Don't ignore cancellation
```swift
// ❌ Wrong - No cancellation support
case .startDownload:
  return .run { send in /* download */ }

// ✅ Correct - Cancellable
case .startDownload:
  return .run { send in /* download */ }
    .cancellable(id: CancelID.download)
```

---

## Rationale

- **Progress feedback**: Users see download status
- **Cancellation**: Users can stop unwanted downloads
- **Background support**: Downloads continue when app suspended

---

## Related Patterns
- [Effect-Patterns.md](../TCA/Effect-Patterns.md)
- [Cancel-ID-Management.md](../TCA/Cancel-ID-Management.md)
