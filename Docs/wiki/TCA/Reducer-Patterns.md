# Reducer Patterns

## Quick Reference
- **When to use**: All feature implementations
- **Enforcement**: Required
- **Impact if violated**: Critical - Architecture breakdown

---

## The Pattern

Every feature uses the `@Reducer` macro with this structure:

```swift
import ComposableArchitecture

@Reducer
struct MyFeature {
  @ObservableState
  struct State: Equatable {
    // State properties
  }

  enum Action {
    // Action cases
  }

  // Dependencies
  @Dependency(\.myClient) var myClient

  // Cancel IDs (if needed)
  private enum CancelID { case fetch }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        // Action handling
      }
    }
  }
}
```

---

## Complete Example

```swift
import ComposableArchitecture
import Foundation

@Reducer
struct FileListFeature {
  @ObservableState
  struct State: Equatable {
    var files: IdentifiedArrayOf<FileCellFeature.State> = []
    var isLoading: Bool = false
    var errorMessage: String?
  }

  enum Action {
    // Lifecycle
    case onAppear

    // User actions
    case refreshButtonTapped
    case deleteFiles(IndexSet)

    // Async responses
    case filesLoaded(Result<[File], Error>)

    // Child feature actions
    case files(IdentifiedActionOf<FileCellFeature>)

    // Parent communication
    case delegate(Delegate)

    enum Delegate: Equatable {
      case authenticationRequired
    }
  }

  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  private enum CancelID { case fetch }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          let files = try await coreDataClient.getFiles()
          await send(.filesLoaded(.success(files)))
        }

      case .refreshButtonTapped:
        state.isLoading = true
        return .run { send in
          await send(.filesLoaded(Result {
            let response = try await serverClient.getFiles()
            return response.body?.contents ?? []
          }))
        }
        .cancellable(id: CancelID.fetch)

      case let .filesLoaded(.success(files)):
        state.isLoading = false
        state.files = IdentifiedArray(uniqueElements: files.map {
          FileCellFeature.State(file: $0)
        })
        return .none

      case let .filesLoaded(.failure(error)):
        state.isLoading = false
        if let serverError = error as? ServerClientError,
           serverError == .unauthorized {
          return .send(.delegate(.authenticationRequired))
        }
        state.errorMessage = error.localizedDescription
        return .none

      case let .deleteFiles(indexSet):
        for index in indexSet {
          state.files.remove(at: index)
        }
        return .none

      case .files:
        return .none

      case .delegate:
        return .none
      }
    }
    .forEach(\.files, action: \.files) {
      FileCellFeature()
    }
  }
}
```

---

## Key Elements

### @ObservableState
Required for TCA 1.22+. Enables automatic observation:

```swift
@ObservableState
struct State: Equatable {
  var value: String = ""  // Automatically observed
}
```

### Action Organization
Group actions by purpose:

```swift
enum Action {
  // 1. Lifecycle
  case onAppear
  case onDisappear

  // 2. User interactions
  case buttonTapped
  case textChanged(String)

  // 3. Async responses
  case response(Result<Data, Error>)

  // 4. Child features
  case child(ChildFeature.Action)

  // 5. Delegation
  case delegate(Delegate)

  enum Delegate: Equatable {
    case didComplete
  }
}
```

### Return Type
Always use `some ReducerOf<Self>`:

```swift
var body: some ReducerOf<Self> {
  // ...
}
```

### Effect Patterns
```swift
// Immediate effect (no async)
return .send(.anotherAction)

// Async effect
return .run { send in
  let result = try await client.fetch()
  await send(.response(.success(result)))
}

// No effect
return .none

// Cancellable effect
return .run { send in /* ... */ }
  .cancellable(id: CancelID.fetch, cancelInFlight: true)

// Cancel existing effect
return .cancel(id: CancelID.fetch)

// Merge effects
return .run { /* ... */ }
  .merge(with: .cancel(id: CancelID.other))
```

---

## Child Feature Integration

### Scope Combinator
For single child features:

```swift
var body: some ReducerOf<Self> {
  Scope(state: \.child, action: \.child) {
    ChildFeature()
  }

  Reduce { state, action in
    // Parent logic
  }
}
```

### ForEach Combinator
For collections of child features:

```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    // Parent logic
  }
  .forEach(\.items, action: \.items) {
    ItemFeature()
  }
}
```

### Optional Child (ifLet)
For optional child features:

```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    // Parent logic
  }
  .ifLet(\.child, action: \.child) {
    ChildFeature()
  }
}
```

---

## Anti-Patterns

### Don't use switch default
```swift
// ❌ Wrong
switch action {
case .onAppear: /* ... */
default: return .none
}

// ✅ Correct - Explicit cases
switch action {
case .onAppear: /* ... */
case .otherAction: return .none
case .delegate: return .none
}
```

### Don't mutate state in effects
```swift
// ❌ Wrong
return .run { send in
  state.isLoading = true  // Compile error
}

// ✅ Correct - Mutate before effect
state.isLoading = true
return .run { send in /* ... */ }
```

### Don't capture state in effects
```swift
// ❌ Wrong - Captures entire state
return .run { send in
  let id = state.fileId  // Captures state
}

// ✅ Correct - Capture specific values
let fileId = state.fileId
return .run { send in
  // Use fileId
}
```

---

## Rationale

- **Predictability**: Consistent structure across all features
- **Testability**: Pure functions with explicit effects
- **Scalability**: Composition via Scope/ForEach/ifLet

---

## Related Patterns
- [Feature-State-Design.md](Feature-State-Design.md)
- [Action-Naming.md](Action-Naming.md)
- [Effect-Patterns.md](Effect-Patterns.md)
- [Delegation-Pattern.md](Delegation-Pattern.md)
