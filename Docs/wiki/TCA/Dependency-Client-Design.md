# Dependency Client Design

## Quick Reference
- **When to use**: Any external service (network, storage, system APIs)
- **Enforcement**: Zero-tolerance (required for all services)
- **Impact if violated**: Critical - Untestable code

---

## The Rule

**NEVER** instantiate services directly. **ALWAYS** use `@DependencyClient` for testability and dependency injection.

---

## Complete Template

```swift
import ComposableArchitecture
import Foundation

// MARK: - Client Definition

@DependencyClient
struct MyClient {
  var fetch: @Sendable () async throws -> Response
  var update: @Sendable (_ value: String) async throws -> Void
  var observe: @Sendable () -> AsyncStream<Event>
}

// MARK: - Dependency Registration

extension DependencyValues {
  var myClient: MyClient {
    get { self[MyClient.self] }
    set { self[MyClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension MyClient: DependencyKey {
  static let liveValue = MyClient(
    fetch: {
      print("📡 MyClient.fetch called")
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(Response.self, from: data)
    },
    update: { value in
      print("📡 MyClient.update called with: \(value)")
      // Implementation
    },
    observe: {
      AsyncStream { continuation in
        // Setup observation
        continuation.onTermination = { _ in
          // Cleanup
        }
      }
    }
  )
}

// MARK: - Test Implementation

extension MyClient {
  static let testValue = MyClient(
    fetch: { Response() },
    update: { _ in },
    observe: { AsyncStream { $0.finish() } }
  )
}
```

---

## Real-World Examples

### ServerClient (HTTP API)
```swift
@DependencyClient
struct ServerClient {
  var registerDevice: @Sendable (_ token: String) async throws -> RegisterDeviceResponse
  var registerUser: @Sendable (_ userData: UserData, _ idToken: String) async throws -> LoginResponse
  var loginUser: @Sendable (_ idToken: String) async throws -> LoginResponse
  var getFiles: @Sendable () async throws -> FileResponse
  var addFile: @Sendable (_ url: URL) async throws -> DownloadFileResponse
}

extension ServerClient: DependencyKey {
  static let liveValue = ServerClient(
    registerDevice: { token in
      print("📡 ServerClient.registerDevice called")
      var request = try await generateRequest(pathPart: "registerDevice", method: "POST")
      // ... implementation
    },
    // ... other methods
  )
}
```

### KeychainClient (Secure Storage)
```swift
@DependencyClient
struct KeychainClient {
  var getUserData: @Sendable () async throws -> UserData
  var setUserData: @Sendable (_ userData: UserData) async throws -> Void
  var getJwtToken: @Sendable () async throws -> String?
  var setJwtToken: @Sendable (_ token: String) async throws -> Void
  var deleteJwtToken: @Sendable () async throws -> Void
  var getUserIdentifier: @Sendable () async throws -> String?
}

extension KeychainClient: DependencyKey {
  static let liveValue = KeychainClient(
    getUserData: {
      print("🔑 KeychainClient.getUserData called")
      // Valet implementation
    },
    // ... other methods
  )
}
```

### DownloadClient (Streaming)
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

extension DownloadClient: DependencyKey {
  static let liveValue = DownloadClient(
    downloadFile: { url, expectedSize in
      AsyncStream { continuation in
        Task {
          // Download with progress reporting
          for await progress in downloadManager.download(url) {
            continuation.yield(progress)
          }
          continuation.finish()
        }
      }
    },
    cancelDownload: { url in
      await downloadManager.cancel(url)
    }
  )
}
```

### FileClient (File System)
```swift
@DependencyClient
struct FileClient {
  var documentsDirectory: @Sendable () -> URL
  var filePath: @Sendable (_ remoteURL: URL) -> URL
  var fileExists: @Sendable (_ url: URL) -> Bool
  var deleteFile: @Sendable (_ url: URL) async throws -> Void
  var moveFile: @Sendable (_ from: URL, _ to: URL) async throws -> Void
}

extension FileClient: DependencyKey {
  static let liveValue = FileClient(
    documentsDirectory: {
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    },
    filePath: { remoteURL in
      let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      return docs.appendingPathComponent(remoteURL.lastPathComponent)
    },
    fileExists: { url in
      FileManager.default.fileExists(atPath: url.path)
    },
    deleteFile: { url in
      try FileManager.default.removeItem(at: url)
    },
    moveFile: { from, to in
      if FileManager.default.fileExists(atPath: to.path) {
        try FileManager.default.removeItem(at: to)
      }
      try FileManager.default.moveItem(at: from, to: to)
    }
  )
}
```

---

## Method Signature Patterns

### Async Throwing
```swift
var fetch: @Sendable () async throws -> Response
var save: @Sendable (_ data: Data) async throws -> Void
```

### Async Non-Throwing
```swift
var cancel: @Sendable () async -> Void
var cleanup: @Sendable () async -> Void
```

### Synchronous
```swift
var fileExists: @Sendable (_ url: URL) -> Bool
var documentsDirectory: @Sendable () -> URL
```

### Streaming
```swift
var observe: @Sendable () -> AsyncStream<Event>
var downloadFile: @Sendable (_ url: URL) -> AsyncStream<Progress>
```

---

## Test Value Patterns

### Simple Stubs
```swift
static let testValue = MyClient(
  fetch: { Response() },
  save: { _ in }
)
```

### Configurable Test Values
```swift
extension MyClient {
  static func test(
    fetch: @escaping @Sendable () async throws -> Response = { Response() },
    save: @escaping @Sendable (Data) async throws -> Void = { _ in }
  ) -> Self {
    MyClient(fetch: fetch, save: save)
  }
}

// Usage in tests
let store = TestStoreOf<MyFeature>(initialState: .init()) {
  MyFeature()
} withDependencies: {
  $0.myClient = .test(
    fetch: { throw TestError.fetchFailed }
  )
}
```

---

## Error Handling

### Custom Error Types
```swift
enum ServerClientError: Error, Equatable {
  case internalServerError(message: String)
  case unauthorized
}

extension ServerClientError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .internalServerError(let message):
      return message
    case .unauthorized:
      return "Session expired - please login again"
    }
  }
}
```

### Error Checking
```swift
// Check HTTP status
private func checkUnauthorized(_ response: URLResponse) throws {
  if let httpResponse = response as? HTTPURLResponse {
    if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
      print("🔒 Unauthorized response: HTTP \(httpResponse.statusCode)")
      throw ServerClientError.unauthorized
    }
  }
}

// Check response body
if let error = response.error {
  if error.message.contains("not authorized") {
    throw ServerClientError.unauthorized
  }
  throw ServerClientError.internalServerError(message: error.message)
}
```

---

## Usage in Reducers

```swift
@Reducer
struct MyFeature {
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.fileClient) var fileClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .fetch:
        return .run { send in
          let response = try await serverClient.getFiles()
          await send(.response(.success(response)))
        }
      }
    }
  }
}
```

---

## Anti-Patterns

### Never instantiate directly
```swift
// ❌ FORBIDDEN
let server = Server()
let result = try await server.fetch()

// ✅ CORRECT
@Dependency(\.serverClient) var serverClient
let result = try await serverClient.fetch()
```

### Never use singletons
```swift
// ❌ FORBIDDEN
final class Server {
  static let shared = Server()
}

// ✅ CORRECT
@DependencyClient
struct ServerClient { /* ... */ }
```

---

## Rationale

- **Testability**: Swap live implementations for test stubs
- **Isolation**: Features don't depend on concrete implementations
- **Configurability**: Different implementations for different environments

---

## Related Patterns
- [Reducer-Patterns.md](Reducer-Patterns.md)
- [Effect-Patterns.md](Effect-Patterns.md)
- [Dependency-Mocking.md](../Testing/Dependency-Mocking.md)
