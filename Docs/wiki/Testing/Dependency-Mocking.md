# Dependency Mocking

## Quick Reference
- **When to use**: Testing features that use dependencies
- **Enforcement**: Required
- **Impact if violated**: High - Untestable code, flaky tests

---

## The Rule

Override dependencies in `withDependencies` closure when creating TestStore. Never call live implementations in tests.

---

## Basic Mocking Pattern

```swift
let store = TestStoreOf<MyFeature>(
  initialState: MyFeature.State()
) {
  MyFeature()
} withDependencies: {
  $0.serverClient.getFiles = {
    FileResponse(body: FileList(contents: [], keyCount: 0), error: nil, requestId: "test")
  }
}
```

---

## Mocking Different Scenarios

### Success Case
```swift
$0.serverClient.loginUser = { _ in
  LoginResponse(
    body: TokenResponse(token: "test-token", expiresAt: nil, sessionId: nil, userId: nil),
    error: nil,
    requestId: "test"
  )
}
```

### Error Case
```swift
$0.serverClient.loginUser = { _ in
  throw ServerClientError.unauthorized
}
```

### Network Error
```swift
$0.serverClient.getFiles = {
  throw URLError(.notConnectedToInternet)
}
```

### Delayed Response
```swift
$0.serverClient.getFiles = {
  try await Task.sleep(for: .milliseconds(100))
  return FileResponse(body: FileList(contents: [], keyCount: 0), error: nil, requestId: "test")
}
```

---

## Common Client Mocks

### ServerClient
```swift
withDependencies: {
  // Success
  $0.serverClient.getFiles = {
    FileResponse(
      body: FileList(contents: testFiles, keyCount: testFiles.count),
      error: nil,
      requestId: "test"
    )
  }

  // Auth error
  $0.serverClient.getFiles = {
    throw ServerClientError.unauthorized
  }

  // Server error
  $0.serverClient.getFiles = {
    FileResponse(
      body: nil,
      error: ErrorResponse(message: "Internal server error"),
      requestId: "test"
    )
  }
}
```

### KeychainClient
```swift
withDependencies: {
  // Has token
  $0.keychainClient.getJwtToken = { "test-jwt-token" }

  // No token
  $0.keychainClient.getJwtToken = { nil }

  // Token storage
  $0.keychainClient.setJwtToken = { token in
    // Can capture to verify
  }
}
```

### CoreDataClient
```swift
withDependencies: {
  // Return cached files
  $0.coreDataClient.getFiles = { testFiles }

  // Cache files (verify called)
  var cachedFiles: [File]?
  $0.coreDataClient.cacheFiles = { files in
    cachedFiles = files
  }
}
```

### FileClient
```swift
withDependencies: {
  // File exists
  $0.fileClient.fileExists = { _ in true }

  // File doesn't exist
  $0.fileClient.fileExists = { _ in false }

  // Documents directory
  $0.fileClient.documentsDirectory = {
    URL(fileURLWithPath: "/tmp/test")
  }
}
```

### AuthenticationClient
```swift
withDependencies: {
  // Authenticated
  $0.authenticationClient.determineLoginStatus = { .authenticated }

  // Unauthenticated
  $0.authenticationClient.determineLoginStatus = { .unauthenticated }
}
```

### DownloadClient
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
      continuation.yield(.failed("Download failed"))
      continuation.finish()
    }
  }
}
```

---

## Capturing Mock Calls

### Verify Method Called
```swift
var loginCalled = false
var loginToken: String?

let store = TestStoreOf<LoginFeature>(
  initialState: LoginFeature.State()
) {
  LoginFeature()
} withDependencies: {
  $0.serverClient.loginUser = { token in
    loginCalled = true
    loginToken = token
    return LoginResponse(...)
  }
}

// After test
#expect(loginCalled)
#expect(loginToken == expectedToken)
```

### Count Method Calls
```swift
var fetchCount = 0

withDependencies: {
  $0.serverClient.getFiles = {
    fetchCount += 1
    return FileResponse(...)
  }
}

// After test
#expect(fetchCount == 1)
```

---

## Mocking Streams

### AsyncStream
```swift
$0.downloadClient.downloadFile = { url, size in
  AsyncStream { continuation in
    // Emit progress updates
    for percent in stride(from: 0, through: 100, by: 25) {
      continuation.yield(.progress(percent: percent))
    }
    continuation.yield(.completed(localURL: testURL))
    continuation.finish()
  }
}
```

### Empty Stream
```swift
$0.downloadClient.downloadFile = { _, _ in
  AsyncStream { $0.finish() }
}
```

---

## Test Value Pattern

### Using Static testValue
```swift
// When default testValue is sufficient
let store = TestStoreOf<MyFeature>(
  initialState: MyFeature.State()
) {
  MyFeature()
}
// Uses default testValue implementations
```

### Extending testValue
```swift
extension ServerClient {
  static func testWith(
    getFiles: @escaping @Sendable () async throws -> FileResponse = { FileResponse(...) }
  ) -> Self {
    var client = Self.testValue
    client.getFiles = getFiles
    return client
  }
}

// Usage
withDependencies: {
  $0.serverClient = .testWith(
    getFiles: { throw ServerClientError.unauthorized }
  )
}
```

---

## Testing Multiple Dependencies

```swift
let store = TestStoreOf<FileListFeature>(
  initialState: FileListFeature.State()
) {
  FileListFeature()
} withDependencies: {
  // Server returns files
  $0.serverClient.getFiles = {
    FileResponse(body: FileList(contents: testFiles, keyCount: 1), error: nil, requestId: "test")
  }

  // CoreData operations
  $0.coreDataClient.getFiles = { [] }  // Start empty
  $0.coreDataClient.cacheFiles = { _ in }

  // File system
  $0.fileClient.fileExists = { _ in false }
}
```

---

## Anti-Patterns

### Don't call live implementations
```swift
// ❌ Wrong - Uses live network
let store = TestStoreOf<MyFeature>(...)
// No withDependencies - uses liveValue!

// ✅ Correct - Mock everything
let store = TestStoreOf<MyFeature>(...) {
  MyFeature()
} withDependencies: {
  $0.serverClient.getFiles = { /* mock */ }
}
```

### Don't share mutable state across tests
```swift
// ❌ Wrong - Shared state
var sharedCount = 0

@Test func test1() async { sharedCount += 1 }
@Test func test2() async { /* sharedCount may be 1 or 0 */ }

// ✅ Correct - Local state per test
@Test func test1() async {
  var count = 0
  // Use count locally
}
```

---

## Rationale

- **Isolation**: Tests don't depend on external services
- **Speed**: No network delays
- **Reliability**: No flaky tests from network issues
- **Control**: Test exact scenarios (errors, edge cases)

---

## Related Patterns
- [TestStore-Usage.md](TestStore-Usage.md)
- [Dependency-Client-Design.md](../TCA/Dependency-Client-Design.md)
