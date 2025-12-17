# AGENTS.md

This document provides comprehensive guidance for AI assistants working on the OfflineMediaDownloaderCompostable iOS project. It covers architecture, conventions, patterns, and workflows specific to this codebase.

---

## Convention Capture System

When working on this codebase, watch for emerging patterns and conventions. Use these detection signals:

| Signal | Level | Examples |
|--------|-------|----------|
| "NEVER", "FORBIDDEN" | Zero-tolerance | Never use @State in TCA views |
| "MUST", "REQUIRED", "ALWAYS" | Required | All dependencies MUST use @DependencyClient |
| "Prefer", repeated decisions | Recommended | Prefer delegate actions for parent communication |
| "Consider", "Might" | Optional | Consider emoji logging prefixes |

When you detect a new convention, document it in `docs/wiki/Meta/Emerging-Conventions.md`.

---

## Project Overview

### Tech Stack
- **iOS 18+**, **Swift 6.1**
- **The Composable Architecture (TCA)** 1.22.2+
- **Valet** for Keychain/Secure Enclave storage
- **CoreData** for local file persistence
- **AWS Backend**: API Gateway, Lambda, S3, SNS

### Project Structure
```
OfflineMediaDownloaderCompostable/
├── App/
│   ├── Features/           # TCA Reducers (MainFeature, DiagnosticFeature)
│   ├── Views/              # SwiftUI Views + co-located Reducers
│   ├── Dependencies/       # Dependency Clients (ServerClient, etc.)
│   ├── Models/             # Data models (File, UserData, responses)
│   └── Extensions/         # Swift extensions
├── MyPackage/              # Swift Package for shared TCA features
└── Constants.swift         # App-wide constants
```

---

## Architecture Diagram

### Feature Hierarchy
```
App Entry Point (OfflineMediaDownloaderApp)
└── RootFeature (launch, auth routing)
    ├── LoginFeature (Sign in with Apple)
    └── MainFeature (TabView container)
        ├── FileListFeature
        │   └── FileCellFeature[] (per-file downloads, playback)
        └── DiagnosticFeature (keychain inspection, debug)
```

### Dependency Graph
```
┌─────────────────┬───────────────────┬────────────────────┐
│ ServerClient    │ KeychainClient    │ AuthenticationClient│
│ (HTTP API)      │ (Valet storage)   │ (Apple ID state)   │
├─────────────────┼───────────────────┼────────────────────┤
│ CoreDataClient  │ DownloadClient    │ FileClient         │
│ (persistence)   │ (URLSession)      │ (Documents dir)    │
└─────────────────┴───────────────────┴────────────────────┘
```

### Data Flow
```
Push Notification → AppDelegate → RootFeature → MainFeature.FileListFeature
                                                      │
Server API ←→ ServerClient                            │
                   │                                  ↓
              FileResponse → CoreDataClient → FileCellFeature[] → UI
```

---

## Critical Project-Specific Rules

### Zero-Tolerance Rules

#### 1. No @State/@StateObject in TCA Views
**NEVER** use SwiftUI state management in views that use TCA stores.

```swift
// ❌ FORBIDDEN - SwiftUI state in TCA view
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
  @State private var localValue: String = ""  // NEVER do this
}

// ✅ CORRECT - All state in reducer
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
  // All state managed by store
}
```

#### 2. @DependencyClient Required for All Services
**NEVER** instantiate services directly. Always use `@DependencyClient`.

```swift
// ❌ FORBIDDEN - Direct instantiation
let server = Server()
let result = try await server.getFiles()

// ✅ CORRECT - Dependency injection
@Dependency(\.serverClient) var serverClient
let result = try await serverClient.getFiles()
```

#### 3. Delegate Actions for Parent Communication
**NEVER** use NotificationCenter or global state for feature communication.

```swift
// ❌ FORBIDDEN - NotificationCenter
NotificationCenter.default.post(name: .loginComplete, object: nil)

// ✅ CORRECT - Delegate action
return .send(.delegate(.loginCompleted))
```

### Required Patterns

#### 1. @ObservableState on All State Structs
TCA 1.22+ requires `@ObservableState` for automatic observation.

```swift
@Reducer
struct MyFeature {
  @ObservableState  // REQUIRED
  struct State: Equatable {
    var value: String = ""
  }
}
```

#### 2. Cancel IDs for Async Operations
Prevent memory leaks by using cancel IDs for long-running effects.

```swift
private enum CancelID { case download, signIn, fetch }

// In reducer body:
return .run { send in
  // async work
}
.cancellable(id: CancelID.download, cancelInFlight: true)
```

#### 3. liveValue + testValue for Dependencies
All dependency clients MUST provide both implementations.

```swift
extension MyClient: DependencyKey {
  static let liveValue = MyClient(/* production */)
}

extension MyClient {
  static let testValue = MyClient(/* stubs */)
}
```

---

## TCA Patterns Reference

### Reducer Template
```swift
import ComposableArchitecture

@Reducer
struct MyFeature {
  @ObservableState
  struct State: Equatable {
    var value: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
  }

  enum Action {
    case onAppear
    case valueChanged(String)
    case response(Result<Response, Error>)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case didComplete
    }
  }

  @Dependency(\.myClient) var myClient

  private enum CancelID { case fetch }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true
        return .run { send in
          await send(.response(Result { try await myClient.fetch() }))
        }
        .cancellable(id: CancelID.fetch)

      case let .valueChanged(newValue):
        state.value = newValue
        return .none

      case let .response(.success(data)):
        state.isLoading = false
        // Handle success
        return .none

      case let .response(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
```

### Dependency Client Template
```swift
import ComposableArchitecture
import Foundation

@DependencyClient
struct MyClient {
  var fetch: @Sendable () async throws -> Response
  var update: @Sendable (_ value: String) async throws -> Void
}

extension DependencyValues {
  var myClient: MyClient {
    get { self[MyClient.self] }
    set { self[MyClient.self] = newValue }
  }
}

extension MyClient: DependencyKey {
  static let liveValue = MyClient(
    fetch: {
      print("📡 MyClient.fetch called")
      // Production implementation
    },
    update: { value in
      print("📡 MyClient.update called with: \(value)")
      // Production implementation
    }
  )
}

extension MyClient {
  static let testValue = MyClient(
    fetch: { Response() },
    update: { _ in }
  )
}
```

### View Integration Template
```swift
import SwiftUI
import ComposableArchitecture

struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>

  var body: some View {
    VStack {
      TextField("Value", text: $store.value.sending(\.valueChanged))

      if store.isLoading {
        ProgressView()
      }

      Button("Submit") {
        store.send(.submitButtonTapped)
      }
    }
    .onAppear { store.send(.onAppear) }
    .alert(
      "Error",
      isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { if !$0 { store.send(.clearError) } }
      )
    ) {
      Button("OK") { store.send(.clearError) }
    } message: {
      Text(store.errorMessage ?? "")
    }
  }
}
```

### Child Feature Scoping
```swift
// Parent reducer
var body: some ReducerOf<Self> {
  Scope(state: \.child, action: \.child) {
    ChildFeature()
  }

  Reduce { state, action in
    switch action {
    case .child(.delegate(.didComplete)):
      // Handle child completion
      return .none
    case .child:
      return .none
    }
  }
}

// Parent view
ChildView(store: store.scope(state: \.child, action: \.child))
```

### Collection of Child Features
```swift
// State
var items: IdentifiedArrayOf<ItemFeature.State> = []

// Reducer body
.forEach(\.items, action: \.items) {
  ItemFeature()
}

// View
ForEach(store.scope(state: \.items, action: \.items)) { itemStore in
  ItemView(store: itemStore)
}
```

---

## Wiki Conventions

See `docs/wiki/` for detailed documentation on each topic:

### Conventions/
- [Naming-Conventions.md](docs/wiki/Conventions/Naming-Conventions.md) - PascalCase, camelCase rules
- [Git-Workflow.md](docs/wiki/Conventions/Git-Workflow.md) - Conventional commits
- [Import-Organization.md](docs/wiki/Conventions/Import-Organization.md) - Import ordering
- [File-Organization.md](docs/wiki/Conventions/File-Organization.md) - Feature grouping

### TCA/
- [Reducer-Patterns.md](docs/wiki/TCA/Reducer-Patterns.md) - @Reducer macro usage
- [Feature-State-Design.md](docs/wiki/TCA/Feature-State-Design.md) - State modeling
- [Action-Naming.md](docs/wiki/TCA/Action-Naming.md) - Action naming conventions
- [Delegation-Pattern.md](docs/wiki/TCA/Delegation-Pattern.md) - Child→parent communication
- [Effect-Patterns.md](docs/wiki/TCA/Effect-Patterns.md) - Async effects, streams
- [Dependency-Client-Design.md](docs/wiki/TCA/Dependency-Client-Design.md) - Client architecture
- [Cancel-ID-Management.md](docs/wiki/TCA/Cancel-ID-Management.md) - Effect cancellation

### Views/
- [Store-Integration.md](docs/wiki/Views/Store-Integration.md) - @Bindable usage
- [Binding-Patterns.md](docs/wiki/Views/Binding-Patterns.md) - Two-way bindings
- [Child-Feature-Scoping.md](docs/wiki/Views/Child-Feature-Scoping.md) - store.scope()
- [Navigation-Patterns.md](docs/wiki/Views/Navigation-Patterns.md) - Sheets, covers, links

### Testing/
- [TestStore-Usage.md](docs/wiki/Testing/TestStore-Usage.md) - TestStoreOf patterns
- [Dependency-Mocking.md](docs/wiki/Testing/Dependency-Mocking.md) - Test values
- [Swift-Testing-Patterns.md](docs/wiki/Testing/Swift-Testing-Patterns.md) - @Test macro

### Infrastructure/
- [CoreData-Integration.md](docs/wiki/Infrastructure/CoreData-Integration.md) - Upsert patterns
- [Keychain-Storage-Valet.md](docs/wiki/Infrastructure/Keychain-Storage-Valet.md) - Valet usage
- [Push-Notification-Flow.md](docs/wiki/Infrastructure/Push-Notification-Flow.md) - APNS routing
- [Background-Downloads.md](docs/wiki/Infrastructure/Background-Downloads.md) - URLSession
- [Environment-Configuration.md](docs/wiki/Infrastructure/Environment-Configuration.md) - xcconfig

---

## Development Workflow

### Build & Run
```bash
# Open Xcode project
open OfflineMediaDownloaderCompostable/OfflineMediaDownloader.xcodeproj

# Build MyPackage (SPM)
cd OfflineMediaDownloaderCompostable/MyPackage
swift build
swift test
```

### Environment Setup
Configure `Development.xcconfig` with:
```
MEDIA_DOWNLOADER_API_KEY = your-api-key
MEDIA_DOWNLOADER_BASE_PATH = https://your-api-gateway.execute-api.region.amazonaws.com/prod
```

Note: `//` must be escaped as `$()` in xcconfig files.

### Pre-Commit Checklist
- [ ] Build succeeds (Cmd+B)
- [ ] All tests pass (Cmd+U)
- [ ] No @State in TCA views
- [ ] All new dependencies have testValue
- [ ] Cancel IDs for new async operations
- [ ] Delegate actions for parent communication

---

## Feature Implementation Checklist

When adding a new feature:

1. **Create Reducer**
   - [ ] `@Reducer` struct with `@ObservableState` State
   - [ ] Action enum with delegate cases
   - [ ] `@Dependency` declarations
   - [ ] `CancelID` enum for async ops
   - [ ] `body` with `ReducerOf<Self>` return type

2. **Create View**
   - [ ] `@Bindable var store: StoreOf<Feature>`
   - [ ] No `@State` or `@StateObject`
   - [ ] `.onAppear { store.send(.onAppear) }`
   - [ ] Scoped stores for child features

3. **Integrate with Parent**
   - [ ] Add state property to parent
   - [ ] Add action cases to parent
   - [ ] `Scope()` in parent reducer body
   - [ ] Handle delegate actions

4. **Add Dependencies**
   - [ ] `@DependencyClient` struct
   - [ ] `DependencyValues` extension
   - [ ] `liveValue` implementation
   - [ ] `testValue` implementation

5. **Testing**
   - [ ] `TestStoreOf<Feature>` setup
   - [ ] Test each action pathway
   - [ ] Verify state mutations
   - [ ] Test delegate emissions

---

## Common Development Tasks

### Adding a New API Endpoint

1. Add method to `ServerClient`:
```swift
@DependencyClient
struct ServerClient {
  // existing methods...
  var newEndpoint: @Sendable (_ param: String) async throws -> Response
}
```

2. Implement in `liveValue`:
```swift
newEndpoint: { param in
  print("📡 ServerClient.newEndpoint called")
  var request = try await generateRequest(pathPart: "endpoint", method: "POST")
  // ... implementation
}
```

3. Add to `testValue`:
```swift
newEndpoint: { _ in Response() }
```

### Adding a New Dependency Client

See [Dependency-Client-Design.md](docs/wiki/TCA/Dependency-Client-Design.md) for the full template.

1. Create file in `App/Dependencies/`
2. Define `@DependencyClient` struct
3. Extend `DependencyValues`
4. Conform to `DependencyKey` with `liveValue`
5. Add `testValue` extension

### Handling Auth Errors

ServerClient throws `ServerClientError.unauthorized` on 401/403. Propagate to parent via delegate:

```swift
case let .response(.failure(error)):
  if let serverError = error as? ServerClientError, serverError == .unauthorized {
    return .send(.delegate(.authenticationRequired))
  }
  state.errorMessage = error.localizedDescription
  return .none
```

### State Preservation During Refresh

When refreshing data, preserve UI state (downloads, selections):

```swift
case let .response(.success(newItems)):
  let existingStates = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, $0) })
  state.items = IdentifiedArray(uniqueElements: newItems.map { item in
    var newState = ItemFeature.State(item: item)
    if let existing = existingStates[item.id] {
      newState.isDownloading = existing.isDownloading
      newState.downloadProgress = existing.downloadProgress
    }
    return newState
  })
```

---

## Logging Conventions

### Recommended Emoji Prefixes
Use emoji prefixes to categorize log output:

| Emoji | Category | Example |
|-------|----------|---------|
| 📡 | Network/API | `print("📡 ServerClient.getFiles called")` |
| 🔑 | Authentication/Keychain | `print("🔑 Token found")` |
| 📁 | CoreData/Storage | `print("📁 Caching \(files.count) files")` |
| 📥 | Downloads | `print("📥 Download started: \(url)")` |
| 🎬 | Video/Playback | `print("🎬 Playing: \(filename)")` |
| ❌ | Errors | `print("❌ Download failed: \(error)")` |
| ⚠️ | Warnings | `print("⚠️ File not found")` |
| 🔒 | Auth status | `print("🔒 Unauthorized response")` |

This is a recommended convention, not enforced.

---

## Key Files Reference

### Feature Reducers
| File | Feature | Responsibility |
|------|---------|----------------|
| `App/Views/RootView.swift` | RootFeature | App entry, auth routing |
| `App/Features/MainFeature.swift` | MainFeature | Tab navigation |
| `App/Views/LoginView.swift` | LoginFeature | Sign in with Apple |
| `App/Views/FileListView.swift` | FileListFeature, FileCellFeature | File list, downloads |
| `App/Features/DiagnosticFeature.swift` | DiagnosticFeature | Keychain inspection |

### Dependency Clients
| File | Client | Responsibility |
|------|--------|----------------|
| `App/Dependencies/ServerClient.swift` | ServerClient | HTTP API |
| `App/Dependencies/KeychainClient.swift` | KeychainClient | Valet storage |
| `App/Dependencies/AuthenticationClient.swift` | AuthenticationClient | Apple ID state |
| `App/Dependencies/CoreDataClient.swift` | CoreDataClient | File persistence |
| `App/Dependencies/DownloadClient.swift` | DownloadClient | URLSession downloads |

---

## Support Resources

- **TCA Documentation**: https://pointfreeco.github.io/swift-composable-architecture/
- **Valet Documentation**: https://github.com/square/Valet
- **Swift Testing**: https://developer.apple.com/documentation/testing
- **Wiki Conventions**: `docs/wiki/`
