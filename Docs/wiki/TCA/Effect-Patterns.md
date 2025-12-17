# Effect Patterns

## Quick Reference
- **When to use**: Any async operations in reducers
- **Enforcement**: Required
- **Impact if violated**: High - Memory leaks, race conditions

---

## The Rule

All side effects (network calls, file I/O, timers) must be performed inside `Effect` using `.run`, `.send`, or other effect builders.

---

## Basic Effect Patterns

### No Effect
```swift
case .buttonTapped:
  state.count += 1
  return .none
```

### Immediate Send
```swift
case .buttonTapped:
  return .send(.anotherAction)
```

### Async Effect
```swift
case .fetchData:
  return .run { send in
    let data = try await client.fetch()
    await send(.dataLoaded(data))
  }
```

### Effect with Result
```swift
case .fetchData:
  return .run { send in
    await send(.response(Result {
      try await client.fetch()
    }))
  }
```

---

## Cancellation Patterns

### Define Cancel IDs
```swift
private enum CancelID {
  case fetch
  case download
  case search
}
```

### Cancellable Effect
```swift
case .startFetch:
  return .run { send in
    let data = try await client.fetch()
    await send(.fetchCompleted(data))
  }
  .cancellable(id: CancelID.fetch)
```

### Cancel In-Flight
Automatically cancels previous effect when new one starts:

```swift
case .search(let query):
  return .run { send in
    try await Task.sleep(for: .milliseconds(300))  // Debounce
    let results = try await client.search(query)
    await send(.searchResults(results))
  }
  .cancellable(id: CancelID.search, cancelInFlight: true)
```

### Manual Cancellation
```swift
case .cancelButtonTapped:
  return .cancel(id: CancelID.fetch)
```

### Merge with Cancellation
```swift
case .cancelDownload:
  state.isDownloading = false
  return .run { _ in
    await downloadClient.cancelDownload(url)
  }
  .merge(with: .cancel(id: CancelID.download))
```

---

## Streaming Patterns

### AsyncStream Consumption
```swift
case .startDownload:
  state.isDownloading = true
  let url = state.file.url!
  let size = Int64(state.file.size ?? 0)

  return .run { send in
    let stream = downloadClient.downloadFile(url, size)
    for await progress in stream {
      switch progress {
      case let .progress(percent):
        await send(.progressUpdated(Double(percent) / 100.0))
      case let .completed(localURL):
        await send(.downloadCompleted(localURL))
      case let .failed(message):
        await send(.downloadFailed(message))
      }
    }
  }
  .cancellable(id: CancelID.download, cancelInFlight: true)
```

### Timer Effect
```swift
case .startTimer:
  return .run { send in
    for await _ in AsyncTimerSequence(interval: .seconds(1), clock: .continuous) {
      await send(.tick)
    }
  }
  .cancellable(id: CancelID.timer)
```

---

## Error Handling Patterns

### Try-Catch in Effect
```swift
case .fetchData:
  return .run { send in
    do {
      let data = try await client.fetch()
      await send(.success(data))
    } catch {
      await send(.failure(error.localizedDescription))
    }
  }
```

### Result Pattern
```swift
case .fetchData:
  return .run { send in
    await send(.response(Result {
      try await client.fetch()
    }))
  }

case let .response(.success(data)):
  state.data = data
  return .none

case let .response(.failure(error)):
  state.errorMessage = error.localizedDescription
  return .none
```

### Auth Error Escalation
```swift
case let .response(.failure(error)):
  if let serverError = error as? ServerClientError,
     serverError == .unauthorized {
    return .send(.delegate(.authenticationRequired))
  }
  state.errorMessage = error.localizedDescription
  return .none
```

---

## Multiple Effects

### Merge Effects
Run effects concurrently:

```swift
case .loadAll:
  return .merge(
    .run { send in
      let users = try await userClient.fetch()
      await send(.usersLoaded(users))
    },
    .run { send in
      let files = try await fileClient.fetch()
      await send(.filesLoaded(files))
    }
  )
```

### Concatenate Effects
Run effects sequentially:

```swift
case .saveAndRefresh:
  return .concatenate(
    .run { _ in
      try await saveClient.save(data)
    },
    .run { send in
      let updated = try await fetchClient.fetch()
      await send(.refreshed(updated))
    }
  )
```

---

## Capturing Values

### Correct - Capture Before Effect
```swift
case .downloadFile:
  let fileId = state.fileId
  let url = state.url
  return .run { send in
    // Use captured values
    let result = try await downloadClient.download(url)
    await send(.downloaded(fileId, result))
  }
```

### Incorrect - Capture State
```swift
// ❌ WRONG - Captures entire state
case .downloadFile:
  return .run { send in
    let url = state.url  // Compile error - state not accessible
  }
```

### Capture Dependencies
```swift
case .fetchData:
  return .run { [client = self.client] send in
    let data = try await client.fetch()
    await send(.loaded(data))
  }
```

---

## Fire-and-Forget Effects

When you don't need to send actions back:

```swift
case .logEvent:
  return .run { _ in
    try? await analyticsClient.log("event")
  }

case .deleteFile:
  return .run { _ in
    try await fileClient.delete(url)
  }
```

---

## Anti-Patterns

### Don't block with sync operations
```swift
// ❌ Wrong - Blocks reducer
case .checkFile:
  let exists = FileManager.default.fileExists(atPath: path)
  return .none

// ✅ Correct - Async check
case .checkFile:
  return .run { send in
    let exists = FileManager.default.fileExists(atPath: path)
    await send(.fileExists(exists))
  }
```

### Don't forget cancellation for long-running effects
```swift
// ❌ Wrong - No way to cancel
case .startPolling:
  return .run { send in
    while true {
      try await Task.sleep(for: .seconds(5))
      await send(.poll)
    }
  }

// ✅ Correct - Cancellable
case .startPolling:
  return .run { send in
    while true {
      try await Task.sleep(for: .seconds(5))
      await send(.poll)
    }
  }
  .cancellable(id: CancelID.polling)
```

---

## Rationale

- **Testability**: Effects can be controlled in tests
- **Cancellation**: Prevents memory leaks and orphaned tasks
- **Predictability**: Clear async boundaries

---

## Related Patterns
- [Reducer-Patterns.md](Reducer-Patterns.md)
- [Cancel-ID-Management.md](Cancel-ID-Management.md)
- [Dependency-Client-Design.md](Dependency-Client-Design.md)
