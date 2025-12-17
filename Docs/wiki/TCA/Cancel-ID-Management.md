# Cancel ID Management

## Quick Reference
- **When to use**: Any async effect that might need cancellation
- **Enforcement**: Required
- **Impact if violated**: High - Memory leaks, orphaned tasks

---

## The Rule

All long-running or user-interruptible effects MUST use cancel IDs. This prevents memory leaks and ensures clean cancellation.

---

## Basic Pattern

```swift
@Reducer
struct MyFeature {
  // Define cancel IDs as private enum
  private enum CancelID {
    case fetch
    case download
    case search
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .startFetch:
        return .run { send in
          let data = try await client.fetch()
          await send(.fetchCompleted(data))
        }
        .cancellable(id: CancelID.fetch)

      case .cancelFetch:
        return .cancel(id: CancelID.fetch)
      }
    }
  }
}
```

---

## Cancel ID Naming

Use descriptive names that match the operation:

```swift
private enum CancelID {
  case fetch        // Single fetch operation
  case download     // File download
  case search       // Search query
  case signIn       // Authentication
  case refresh      // Data refresh
  case polling      // Periodic polling
  case timer        // Timer-based effects
  case observation  // Continuous observation
}
```

---

## Cancellation Patterns

### Basic Cancellable
```swift
return .run { send in
  let result = try await client.fetch()
  await send(.loaded(result))
}
.cancellable(id: CancelID.fetch)
```

### Cancel In-Flight
Automatically cancels previous effect when a new one starts:

```swift
// Search with debouncing - each new search cancels the previous
case let .searchQueryChanged(query):
  return .run { send in
    try await Task.sleep(for: .milliseconds(300))
    let results = try await searchClient.search(query)
    await send(.searchResults(results))
  }
  .cancellable(id: CancelID.search, cancelInFlight: true)
```

### Manual Cancellation
```swift
case .cancelButtonTapped:
  return .cancel(id: CancelID.download)
```

### Cancellation with Cleanup
```swift
case .cancelDownload:
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

## Per-Item Cancel IDs

For collections where each item has its own effect:

```swift
private enum CancelID {
  case download(fileId: String)
}

// Start download for specific file
case let .downloadFile(fileId):
  return .run { send in
    // ... download logic
  }
  .cancellable(id: CancelID.download(fileId: fileId))

// Cancel specific file's download
case let .cancelDownload(fileId):
  return .cancel(id: CancelID.download(fileId: fileId))
```

---

## Real-World Examples

### Download with Progress
```swift
@Reducer
struct FileCellFeature {
  private enum CancelID { case download }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
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
      }
    }
  }
}
```

### Authentication Flow
```swift
@Reducer
struct LoginFeature {
  private enum CancelID { case signIn }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .signInWithAppleCompleted(.success(authorization)):
        return .run { send in
          // Process authorization
          await send(.loginResponse(Result {
            try await serverClient.loginUser(idToken: token)
          }))
        }
        .cancellable(id: CancelID.signIn, cancelInFlight: true)

      case .cancelSignIn:
        state.isSigningIn = false
        return .cancel(id: CancelID.signIn)
      }
    }
  }
}
```

### Debounced Search
```swift
@Reducer
struct SearchFeature {
  private enum CancelID { case search }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .queryChanged(query):
        state.query = query

        guard !query.isEmpty else {
          state.results = []
          return .cancel(id: CancelID.search)
        }

        return .run { send in
          try await Task.sleep(for: .milliseconds(300))
          let results = try await searchClient.search(query)
          await send(.resultsLoaded(results))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
      }
    }
  }
}
```

---

## When to Use Cancel IDs

| Scenario | Use Cancel ID? |
|----------|----------------|
| Network request that user can cancel | Yes |
| Download with progress | Yes |
| Search with debouncing | Yes |
| Timer/polling | Yes |
| One-shot fire-and-forget | No |
| Quick synchronous-like operation | Usually no |

---

## Anti-Patterns

### Missing cancel ID for interruptible operations
```swift
// ❌ Wrong - No way to cancel
case .startDownload:
  return .run { send in
    for await progress in downloadClient.download(url) {
      await send(.progress(progress))
    }
  }

// ✅ Correct - Cancellable
case .startDownload:
  return .run { send in
    for await progress in downloadClient.download(url) {
      await send(.progress(progress))
    }
  }
  .cancellable(id: CancelID.download)
```

### Forgetting to cancel on state reset
```swift
// ❌ Wrong - Effect continues after logout
case .logout:
  state = State()
  return .none

// ✅ Correct - Cancel ongoing effects
case .logout:
  state = State()
  return .cancel(id: CancelID.fetch)
```

### Using same cancel ID for unrelated operations
```swift
// ❌ Wrong - Cancelling search might cancel download
private enum CancelID {
  case operation  // Too generic
}

// ✅ Correct - Distinct IDs
private enum CancelID {
  case search
  case download
}
```

---

## Rationale

- **Memory safety**: Prevents leaked tasks and memory
- **User experience**: Allows clean cancellation of operations
- **Predictability**: Clear lifecycle for async operations
- **Testing**: Effects can be verified as cancelled

---

## Related Patterns
- [Effect-Patterns.md](Effect-Patterns.md)
- [Reducer-Patterns.md](Reducer-Patterns.md)
