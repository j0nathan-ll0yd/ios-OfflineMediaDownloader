# Action Naming

## Quick Reference
- **When to use**: Defining actions for any feature
- **Enforcement**: Required
- **Impact if violated**: Medium - Inconsistent API, confusion

---

## The Rule

Actions should clearly describe what happened or what the user did. Use consistent naming patterns based on action type.

---

## Action Categories

### 1. Lifecycle Actions
Triggered by view lifecycle:

```swift
case onAppear
case onDisappear
case task  // For .task modifier
```

### 2. User Interaction Actions
Named as `<element><verb>` or `<element>Tapped`:

```swift
// Buttons
case loginButtonTapped
case refreshButtonTapped
case downloadButtonTapped
case cancelButtonTapped
case deleteButtonTapped

// Forms
case emailChanged(String)
case passwordChanged(String)
case valueChanged(String)

// Selections
case tabSelected(Tab)
case fileSelected(File)
case itemTapped(Item.ID)

// Gestures
case itemSwiped(Item.ID)
case dragEnded(CGFloat)
```

### 3. Async Response Actions
Named as `<noun>Response` or `<verb>Completed`:

```swift
// Result-based
case loginResponse(Result<LoginResponse, Error>)
case filesResponse(Result<FileResponse, Error>)
case downloadResponse(Result<URL, Error>)

// Success/Failure split
case filesLoaded([File])
case loadingFailed(Error)

// Progress updates
case downloadProgressUpdated(Double)
case downloadCompleted(URL)
case downloadFailed(String)
```

### 4. Child Feature Actions
Named as `<childName>(<ChildAction>)`:

```swift
// Single child
case login(LoginFeature.Action)
case fileList(FileListFeature.Action)

// Collection (IdentifiedAction)
case files(IdentifiedActionOf<FileCellFeature>)
case items(IdentifiedActionOf<ItemFeature>)
```

### 5. Delegate Actions
Nested enum describing what happened:

```swift
case delegate(Delegate)

enum Delegate: Equatable {
  case loginCompleted
  case registrationCompleted
  case authenticationRequired
  case fileDeleted(File)
  case playFile(File)
}
```

### 6. Internal/Setter Actions
For state updates triggered by effects:

```swift
case setError(String)
case clearError
case setLoading(Bool)
case checkFileExistence(Bool)
```

---

## Complete Example

```swift
enum Action {
  // Lifecycle
  case onAppear
  case task

  // User interactions
  case refreshButtonTapped
  case addButtonTapped
  case deleteButtonTapped
  case confirmationDismissed

  // State setters
  case setError(String)
  case clearError
  case setLoading(Bool)

  // Async responses
  case filesLoaded(Result<[File], Error>)
  case addFileResponse(Result<DownloadFileResponse, Error>)

  // Child features
  case files(IdentifiedActionOf<FileCellFeature>)

  // Push notification actions
  case fileAddedFromPush(File)
  case updateFileUrl(fileId: String, url: URL)

  // Delegation to parent
  case delegate(Delegate)

  enum Delegate: Equatable {
    case authenticationRequired
  }
}
```

---

## Naming Patterns

### Verb Tense Guidelines

| Context | Tense | Example |
|---------|-------|---------|
| User tapped something | Past | `loginButtonTapped` |
| Value changed | Past | `valueChanged(String)` |
| Async completed | Past | `downloadCompleted` |
| Request started | Present | `loadFiles` (rare) |
| Set state | Imperative | `setError`, `clearError` |

### Associated Value Naming

```swift
// Result types
case response(Result<Data, Error>)

// Simple values - type implies meaning
case valueChanged(String)
case progressUpdated(Double)

// Multiple values - use labels
case updateFileUrl(fileId: String, url: URL)
case downloadProgress(fileId: String, percent: Int)
```

---

## Anti-Patterns

### Don't use vague names
```swift
// ❌ Wrong
case action1
case doSomething
case handle

// ✅ Correct
case loginButtonTapped
case refreshFiles
case handleAuthError
```

### Don't mix tenses inconsistently
```swift
// ❌ Wrong
case tap          // Present
case tapped       // Past
case willTap      // Future

// ✅ Correct - Consistent past tense
case buttonTapped
case valueChanged
case itemSelected
```

### Don't include "action" in names
```swift
// ❌ Wrong
case loginAction
case refreshAction

// ✅ Correct
case loginButtonTapped
case refreshButtonTapped
```

---

## Delegate Action Naming

Delegate actions describe events that happened:

```swift
enum Delegate: Equatable {
  // ✅ Good - Describes what happened
  case loginCompleted
  case authenticationRequired
  case fileDeleted(File)

  // ❌ Bad - Commands to parent
  case doLogout
  case showError
}
```

---

## Rationale

- **Readability**: Clear action names make reducer logic self-documenting
- **Consistency**: Predictable patterns reduce cognitive load
- **Debugging**: Action names appear in logs and time-travel debugging

---

## Related Patterns
- [Reducer-Patterns.md](Reducer-Patterns.md)
- [Delegation-Pattern.md](Delegation-Pattern.md)
