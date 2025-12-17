# Swift Testing Patterns

## Quick Reference
- **When to use**: All unit tests in the project
- **Enforcement**: Required (use Swift Testing, not XCTest)
- **Impact if violated**: Low - Tests still work, but inconsistent

---

## The Rule

Use Swift Testing framework (`import Testing`) with `@Test` macro. Mark async tests with `@MainActor` for TCA features.

---

## Basic Test Structure

```swift
import Testing
import ComposableArchitecture

@testable import OfflineMediaDownloader

@MainActor
struct MyFeatureTests {
  @Test func basicTest() async throws {
    // Test implementation
  }
}
```

---

## Test Attributes

### @Test
Mark functions as tests:

```swift
@Test func myTest() async throws {
  // Test code
}
```

### @MainActor
Required for TCA tests (TestStore requires MainActor):

```swift
@MainActor
@Test func tcaTest() async throws {
  let store = TestStoreOf<MyFeature>(...)
  // ...
}
```

### Descriptive Names
```swift
@Test("User can login with valid credentials")
func loginWithValidCredentials() async throws {
  // ...
}

@Test("Shows error when network unavailable")
func networkError() async throws {
  // ...
}
```

---

## Expectations

### Basic Expectations
```swift
#expect(value == expected)
#expect(value != other)
#expect(condition)
#expect(!condition)
```

### Optional Expectations
```swift
#expect(optionalValue != nil)
#expect(optionalValue == nil)

// Unwrap optional
let unwrapped = try #require(optionalValue)
```

### Collection Expectations
```swift
#expect(array.isEmpty)
#expect(array.count == 5)
#expect(array.contains(item))
```

### Error Expectations
```swift
// Expect error to be thrown
#expect(throws: MyError.self) {
  try throwingFunction()
}

// Expect specific error
#expect(throws: MyError.specificCase) {
  try throwingFunction()
}
```

---

## Test Organization

### Grouping by Feature
```swift
@MainActor
struct FileListFeatureTests {
  // MARK: - Loading

  @Test func loadsFilesOnAppear() async throws { }

  @Test func showsLoadingIndicator() async throws { }

  // MARK: - Refresh

  @Test func refreshFetchesFromServer() async throws { }

  // MARK: - Errors

  @Test func handlesNetworkError() async throws { }

  @Test func handlesAuthError() async throws { }
}
```

### Separate Test Files
```
Tests/
├── FileListFeatureTests.swift
├── LoginFeatureTests.swift
├── ServerClientTests.swift
└── KeychainClientTests.swift
```

---

## TCA Test Patterns

### Testing Actions
```swift
@MainActor
@Test func buttonTapUpdatesState() async throws {
  let store = TestStoreOf<MyFeature>(
    initialState: MyFeature.State()
  ) {
    MyFeature()
  }

  await store.send(.buttonTapped) {
    $0.tapped = true
  }
}
```

### Testing Effects
```swift
@MainActor
@Test func fetchLoadsData() async throws {
  let store = TestStoreOf<MyFeature>(
    initialState: MyFeature.State()
  ) {
    MyFeature()
  } withDependencies: {
    $0.client.fetch = { TestData.sample }
  }

  await store.send(.fetch) {
    $0.isLoading = true
  }

  await store.receive(\.dataLoaded) {
    $0.isLoading = false
    $0.data = TestData.sample
  }
}
```

### Testing Delegates
```swift
@MainActor
@Test func childDelegateHandled() async throws {
  let store = TestStoreOf<ParentFeature>(
    initialState: ParentFeature.State()
  ) {
    ParentFeature()
  }

  await store.send(.child(.delegate(.completed))) {
    $0.childCompleted = true
  }
}
```

---

## Test Data

### Fixtures
```swift
enum TestData {
  static let sampleFile = File(
    fileId: "test-1",
    key: "video.mp4",
    publishDate: Date(),
    size: 1000,
    url: URL(string: "https://example.com/video.mp4")
  )

  static let sampleFiles = [sampleFile]

  static let sampleUser = UserData(
    email: "test@example.com",
    firstName: "Test",
    lastName: "User",
    identifier: "test-identifier"
  )
}
```

### Using Fixtures
```swift
@Test func displaysFiles() async throws {
  let store = TestStoreOf<FileListFeature>(
    initialState: FileListFeature.State()
  ) {
    FileListFeature()
  } withDependencies: {
    $0.coreDataClient.getFiles = { TestData.sampleFiles }
  }

  await store.send(.onAppear)
  // ...
}
```

---

## Async Testing

### Waiting for Effects
```swift
@MainActor
@Test func asyncOperation() async throws {
  let store = TestStoreOf<MyFeature>(...)

  await store.send(.startOperation)
  await store.receive(\.operationCompleted, timeout: .seconds(1))
}
```

### Testing Streams
```swift
@MainActor
@Test func progressUpdates() async throws {
  let store = TestStoreOf<DownloadFeature>(
    initialState: DownloadFeature.State()
  ) {
    DownloadFeature()
  } withDependencies: {
    $0.downloadClient.downloadFile = { _, _ in
      AsyncStream { continuation in
        continuation.yield(.progress(percent: 50))
        continuation.yield(.completed(localURL: testURL))
        continuation.finish()
      }
    }
  }

  await store.send(.startDownload) {
    $0.isDownloading = true
  }

  await store.receive(\.progressUpdated) {
    $0.progress = 0.5
  }

  await store.receive(\.downloadCompleted) {
    $0.isDownloading = false
    $0.isDownloaded = true
  }
}
```

---

## Parameterized Tests

### Using Arguments
```swift
@Test(arguments: [
  ("valid@email.com", true),
  ("invalid", false),
  ("", false)
])
func emailValidation(email: String, isValid: Bool) {
  let result = validateEmail(email)
  #expect(result == isValid)
}
```

### Multiple Parameters
```swift
@Test(arguments: [1, 2, 3], ["a", "b"])
func combinedTest(number: Int, letter: String) {
  // Tests with (1, "a"), (1, "b"), (2, "a"), (2, "b"), (3, "a"), (3, "b")
}
```

---

## Migration from XCTest

| XCTest | Swift Testing |
|--------|--------------|
| `import XCTest` | `import Testing` |
| `class MyTests: XCTestCase` | `struct MyTests` |
| `func testSomething()` | `@Test func something()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `XCTUnwrap(x)` | `try #require(x)` |
| `setUpWithError()` | Constructor or inline |
| `tearDown()` | deinit or inline |

---

## Anti-Patterns

### Don't mix XCTest and Swift Testing
```swift
// ❌ Wrong - Mixing frameworks
import XCTest
import Testing

class MyTests: XCTestCase {
  @Test func swiftTest() { }  // Won't work as expected
}

// ✅ Correct - Pure Swift Testing
import Testing

struct MyTests {
  @Test func swiftTest() { }
}
```

### Don't forget @MainActor for TCA tests
```swift
// ❌ Wrong - Missing @MainActor
@Test func tcaTest() async throws {
  let store = TestStoreOf<MyFeature>(...)  // Compiler error
}

// ✅ Correct
@MainActor
@Test func tcaTest() async throws {
  let store = TestStoreOf<MyFeature>(...)
}
```

---

## Rationale

- **Modern syntax**: Cleaner than XCTest
- **Better diagnostics**: More helpful error messages
- **Parameterized tests**: Built-in support
- **Swift-native**: Designed for Swift from the ground up

---

## Related Patterns
- [TestStore-Usage.md](TestStore-Usage.md)
- [Dependency-Mocking.md](Dependency-Mocking.md)
