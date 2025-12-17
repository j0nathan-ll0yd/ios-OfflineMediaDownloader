# Delegation Pattern

## Quick Reference
- **When to use**: Child feature needs to communicate with parent
- **Enforcement**: Zero-tolerance (vs NotificationCenter)
- **Impact if violated**: Critical - Architecture breakdown

---

## The Rule

**NEVER** use NotificationCenter, singletons, or global state for feature communication. **ALWAYS** use delegate actions.

---

## The Pattern

### Child Feature
Define a `Delegate` enum inside the `Action` enum:

```swift
@Reducer
struct ChildFeature {
  @ObservableState
  struct State: Equatable { /* ... */ }

  enum Action {
    // Regular actions
    case buttonTapped
    case response(Result<Data, Error>)

    // Delegate actions for parent
    case delegate(Delegate)

    enum Delegate: Equatable {
      case didComplete
      case authenticationRequired
      case itemSelected(Item)
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .buttonTapped:
        // ... do work ...
        return .send(.delegate(.didComplete))

      case let .response(.failure(error)):
        if isAuthError(error) {
          return .send(.delegate(.authenticationRequired))
        }
        return .none

      case .delegate:
        // Parent handles this - return .none
        return .none
      }
    }
  }
}
```

### Parent Feature
Handle delegate actions in the parent:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable {
    var child: ChildFeature.State = ChildFeature.State()
  }

  enum Action {
    case child(ChildFeature.Action)
    // ... other actions
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }

    Reduce { state, action in
      switch action {
      // Handle specific delegate actions
      case .child(.delegate(.didComplete)):
        // Do something when child completes
        return .none

      case .child(.delegate(.authenticationRequired)):
        // Handle auth requirement
        return .send(.logout)

      case let .child(.delegate(.itemSelected(item))):
        // Handle item selection
        state.selectedItem = item
        return .none

      // Ignore other child actions
      case .child:
        return .none
      }
    }
  }
}
```

---

## Real-World Examples

### FileListFeature → MainFeature → RootFeature

```swift
// FileCellFeature
enum Action {
  case delegate(Delegate)
  enum Delegate: Equatable {
    case fileDeleted(File)
    case playFile(File)
  }
}

// FileListFeature handles FileCellFeature delegate
case let .files(.element(id: _, action: .delegate(.fileDeleted(file)))):
  state.files.remove(id: file.fileId)
  return .none

case let .files(.element(id: _, action: .delegate(.playFile(file)))):
  state.playingFile = file
  return .none

// FileListFeature has its own delegate
enum Action {
  case delegate(Delegate)
  enum Delegate: Equatable {
    case authenticationRequired
  }
}

// MainFeature forwards to RootFeature
case .fileList(.delegate(.authenticationRequired)):
  return .send(.delegate(.authenticationRequired))
```

### LoginFeature → RootFeature

```swift
// LoginFeature
enum Action {
  case signInWithAppleCompleted(Result<ASAuthorization, Error>)
  case loginResponse(Result<LoginResponse, Error>)
  case delegate(Delegate)

  enum Delegate: Equatable {
    case loginCompleted
    case registrationCompleted
  }
}

// In reducer
case .loginResponse(.success):
  // Store token, etc.
  return .send(.delegate(.loginCompleted))

// RootFeature handles it
case .login(.delegate(.loginCompleted)):
  state.isAuthenticated = true
  state.main = MainFeature.State()
  return .none
```

---

## Collection Delegation

For `IdentifiedArray` collections, use pattern matching:

```swift
// Parent handling child delegate from collection
case let .files(.element(id: fileId, action: .delegate(.fileDeleted(file)))):
  state.files.remove(id: file.fileId)
  return .none

case let .files(.element(id: _, action: .delegate(.playFile(file)))):
  state.playingFile = file
  return .none

// Catch-all for other child actions
case .files:
  return .none
```

---

## Forwarding Pattern

When a grandchild needs to communicate with grandparent:

```swift
// GrandchildFeature → ChildFeature → ParentFeature

// ChildFeature forwards the delegate
case .grandchild(.delegate(.authRequired)):
  return .send(.delegate(.authenticationRequired))

// ParentFeature handles it
case .child(.delegate(.authenticationRequired)):
  return .send(.logout)
```

---

## Anti-Patterns

### Never use NotificationCenter
```swift
// ❌ FORBIDDEN
NotificationCenter.default.post(name: .loginComplete, object: nil)

// ✅ CORRECT
return .send(.delegate(.loginCompleted))
```

### Never use singletons for state
```swift
// ❌ FORBIDDEN
AppState.shared.isLoggedIn = true

// ✅ CORRECT
return .send(.delegate(.loginCompleted))
// Parent updates its state
```

### Never mutate parent state from child
```swift
// ❌ FORBIDDEN - Would require global/shared state
state.parent.isLoading = true

// ✅ CORRECT - Delegate to parent
return .send(.delegate(.loadingStarted))
```

---

## When to Use Delegation

| Scenario | Use Delegate? |
|----------|---------------|
| Child completed a task | Yes |
| Child needs parent to navigate | Yes |
| Child detected auth error | Yes |
| Child needs shared data | No - pass via state |
| Child needs to trigger parent refresh | Yes |

---

## Delegate vs Binding

| Use Delegate | Use Binding |
|--------------|-------------|
| One-time events | Continuous sync |
| Completion notifications | Form field values |
| Error escalation | Toggle states |
| Navigation requests | Selection states |

---

## Rationale

- **Explicit data flow**: All communication visible in action enum
- **Testability**: Delegate actions can be verified in tests
- **Debugging**: Actions appear in logs and debugger
- **No hidden dependencies**: No global state or singletons

---

## Related Patterns
- [Reducer-Patterns.md](Reducer-Patterns.md)
- [Action-Naming.md](Action-Naming.md)
- [Child-Feature-Scoping.md](../Views/Child-Feature-Scoping.md)
