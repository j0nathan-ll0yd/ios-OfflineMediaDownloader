# TestStore Usage

## Quick Reference
- **When to use**: Testing TCA feature reducers
- **Enforcement**: Required for all features
- **Impact if violated**: High - Untested state transitions

---

## The Rule

Use `TestStoreOf<Feature>` to test all reducer logic. Verify state mutations and effect emissions.

---

## Basic TestStore Pattern

```swift
import Testing
import ComposableArchitecture

@testable import OfflineMediaDownloader

@MainActor
@Test func basicFeatureTest() async throws {
  let store = TestStoreOf<MyFeature>(
    initialState: MyFeature.State()
  ) {
    MyFeature()
  }

  await store.send(.buttonTapped) {
    $0.count = 1
  }
}
```

---

## Complete Test Example

```swift
import Testing
import ComposableArchitecture

@testable import OfflineMediaDownloader

@MainActor
struct FileListFeatureTests {
  @Test func loadFilesFromLocalStorage() async throws {
    let testFiles = [
      File(fileId: "1", key: "video1.mp4", publishDate: Date(), size: 1000, url: nil),
      File(fileId: "2", key: "video2.mp4", publishDate: Date(), size: 2000, url: nil)
    ]

    let store = TestStoreOf<FileListFeature>(
      initialState: FileListFeature.State()
    ) {
      FileListFeature()
    } withDependencies: {
      $0.coreDataClient.getFiles = { testFiles }
    }

    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded) {
      $0.files = IdentifiedArray(uniqueElements: testFiles.map {
        FileCellFeature.State(file: $0)
      })
    }
  }

  @Test func refreshButtonFetchesFromServer() async throws {
    let serverFiles = [
      File(fileId: "1", key: "video1.mp4", publishDate: Date(), size: 1000, url: URL(string: "https://example.com/video1.mp4"))
    ]

    let store = TestStoreOf<FileListFeature>(
      initialState: FileListFeature.State()
    ) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = {
        FileResponse(body: FileList(contents: serverFiles, keyCount: 1), error: nil, requestId: "test")
      }
      $0.coreDataClient.cacheFiles = { _ in }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.files = IdentifiedArray(uniqueElements: serverFiles.map {
        FileCellFeature.State(file: $0)
      })
    }
  }
}
```

---

## Testing State Mutations

### Basic State Change
```swift
await store.send(.incrementButtonTapped) {
  $0.count = 1
}
```

### Multiple Property Changes
```swift
await store.send(.loginButtonTapped) {
  $0.isLoading = true
  $0.errorMessage = nil
}
```

### No State Change Expected
```swift
// When action doesn't change state
await store.send(.delegateAction)
// No closure needed - test fails if state changes
```

---

## Testing Effects

### Receiving Actions from Effects
```swift
await store.send(.fetchData) {
  $0.isLoading = true
}

// Verify the effect sends this action
await store.receive(\.dataLoaded) {
  $0.isLoading = false
  $0.data = expectedData
}
```

### Testing Result-Based Actions
```swift
await store.send(.fetchData)

await store.receive(\.response.success) {
  $0.data = expectedData
}

// Or for failure
await store.receive(\.response.failure) {
  $0.errorMessage = "Network error"
}
```

### Multiple Sequential Effects
```swift
await store.send(.startProcess)

await store.receive(\.step1Completed) {
  $0.step1Done = true
}

await store.receive(\.step2Completed) {
  $0.step2Done = true
}
```

---

## Testing with Dependencies

### Override Dependencies
```swift
let store = TestStoreOf<MyFeature>(
  initialState: MyFeature.State()
) {
  MyFeature()
} withDependencies: {
  $0.serverClient.getFiles = { /* return mock data */ }
  $0.keychainClient.getJwtToken = { "mock-token" }
}
```

### Testing Error Cases
```swift
let store = TestStoreOf<MyFeature>(
  initialState: MyFeature.State()
) {
  MyFeature()
} withDependencies: {
  $0.serverClient.getFiles = {
    throw ServerClientError.unauthorized
  }
}

await store.send(.fetchData)

await store.receive(\.delegate.authenticationRequired)
```

---

## Testing Child Features

### Testing Delegate Actions
```swift
@Test func childDelegateIsHandled() async throws {
  let store = TestStoreOf<ParentFeature>(
    initialState: ParentFeature.State()
  ) {
    ParentFeature()
  }

  // Simulate child sending delegate action
  await store.send(.child(.delegate(.didComplete))) {
    $0.childCompleted = true
  }
}
```

### Testing Collection Child Actions
```swift
@Test func fileCellDelegateHandled() async throws {
  let file = File(fileId: "1", key: "test.mp4", publishDate: Date(), size: 1000, url: nil)

  let store = TestStoreOf<FileListFeature>(
    initialState: FileListFeature.State(
      files: [FileCellFeature.State(file: file)]
    )
  ) {
    FileListFeature()
  }

  await store.send(.files(.element(id: "1", action: .delegate(.fileDeleted(file))))) {
    $0.files = []
  }
}
```

---

## Testing Cancellation

### Effect is Cancelled
```swift
@Test func searchCancelsOnNewQuery() async throws {
  let store = TestStoreOf<SearchFeature>(
    initialState: SearchFeature.State()
  ) {
    SearchFeature()
  } withDependencies: {
    $0.searchClient.search = { query in
      try await Task.sleep(for: .seconds(1))
      return []
    }
  }

  // Start first search
  await store.send(.queryChanged("hello")) {
    $0.query = "hello"
  }

  // Start second search - first should be cancelled
  await store.send(.queryChanged("world")) {
    $0.query = "world"
  }

  // Only receive result for second search
  await store.receive(\.searchResults) {
    $0.results = []
  }
}
```

---

## Test Organization

### Group Related Tests
```swift
@MainActor
struct FileListFeatureTests {
  // MARK: - Loading Tests

  @Test func loadsFilesOnAppear() async throws { }

  @Test func showsLoadingState() async throws { }

  // MARK: - Refresh Tests

  @Test func refreshFetchesFromServer() async throws { }

  @Test func refreshPreservesDownloadState() async throws { }

  // MARK: - Error Tests

  @Test func handlesNetworkError() async throws { }

  @Test func handlesAuthError() async throws { }
}
```

---

## Common Assertions

### State Equality
```swift
await store.send(.action) {
  $0.property = expectedValue
}
```

### Optional State
```swift
await store.send(.setError("Error")) {
  $0.errorMessage = "Error"
}

await store.send(.clearError) {
  $0.errorMessage = nil
}
```

### Collection State
```swift
await store.send(.addItem(item)) {
  $0.items.append(ItemFeature.State(item: item))
}

await store.send(.removeItem(id: "1")) {
  $0.items.remove(id: "1")
}
```

---

## Anti-Patterns

### Don't skip state verification
```swift
// ❌ Wrong - No verification
await store.send(.buttonTapped)

// ✅ Correct - Verify state change
await store.send(.buttonTapped) {
  $0.tapped = true
}
```

### Don't forget to receive effects
```swift
// ❌ Wrong - Effect not received (test hangs or fails)
await store.send(.fetchData) {
  $0.isLoading = true
}
// Missing: await store.receive(\.dataLoaded)

// ✅ Correct
await store.send(.fetchData) {
  $0.isLoading = true
}
await store.receive(\.dataLoaded) {
  $0.isLoading = false
}
```

---

## Rationale

- **Exhaustive testing**: Every state change and effect verified
- **Regression prevention**: Changes caught by failing tests
- **Documentation**: Tests document expected behavior

---

## Related Patterns
- [Dependency-Mocking.md](Dependency-Mocking.md)
- [Swift-Testing-Patterns.md](Swift-Testing-Patterns.md)
