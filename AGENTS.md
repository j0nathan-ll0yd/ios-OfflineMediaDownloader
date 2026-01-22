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

When you detect a new convention, document it in `Docs/wiki/Meta/Emerging-Conventions.md`.

---

## Project Overview

### Tech Stack
- **iOS 26+**, **Swift 6.1**
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

#### 4. iOS 26+ Only - No Backwards Compatibility
**iOS 26 is the minimum deployment target.** NEVER add backwards compatibility code.

```swift
// ❌ FORBIDDEN - availability check for older iOS
@available(iOS 17, *)
func modernFeature() { }

// ❌ FORBIDDEN - runtime availability check
if #available(iOS 18, *) {
    useNewAPI()
} else {
    useFallback()
}

// ❌ FORBIDDEN - unavailability check
if #unavailable(iOS 17) {
    useLegacyAPI()
}

// ✅ CORRECT - just use iOS 26 APIs directly
func modernFeature() {
    useNewAPI()  // Available on iOS 26+, no check needed
}
```

**Rationale:**
- Single deployment target eliminates conditional code complexity
- Full access to iOS 26 APIs without fallbacks
- Cleaner, more maintainable codebase
- No testing burden for multiple iOS versions

**What to do instead:**
- Use iOS 26 APIs directly without availability checks
- If an API doesn't exist in iOS 26, it's not available for this project
- Never add shims or workarounds for older iOS versions

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

## Naming Conventions

### Type Naming

| Pattern | Usage | Examples |
|---------|-------|----------|
| Simple nouns | Domain models | `User`, `File`, `Device` |
| `*View` | SwiftUI views | `FileListView`, `LoginView` |
| `*Feature` | TCA reducers | `FileListFeature`, `LoginFeature` |
| `*Client` | Dependency clients | `ServerClient`, `KeychainClient` |
| `*Response` | API responses | `TokenResponse`, `LoginResponse` |
| `*Error` | Error types | `ServerClientError`, `KeychainError` |

### Property Naming

| Pattern | Format | Examples |
|---------|--------|----------|
| All properties | camelCase | `fileId`, `authorName`, `createdAt` |
| IDs | `<entity>Id` | `fileId`, `userId`, `deviceId` |
| Timestamps | `<action>At` | `createdAt`, `expiresAt` |
| Booleans | `is<Condition>` | `isDownloaded`, `isPending` |

### Enum Values

| Context | Format | Examples |
|---------|--------|----------|
| Swift cases | lowercase | `.queued`, `.downloaded`, `.failed` |
| Raw values (API) | PascalCase | `"Queued"`, `"Downloaded"` |

### File Organization

| Directory | Contents |
|-----------|----------|
| `App/Models/` | Domain models (User, File, Device) |
| `App/Features/` | TCA reducers (*Feature) |
| `App/Views/` | SwiftUI views (*View) |
| `App/Dependencies/` | Dependency clients (*Client) |
| `App/Enums/` | Shared enumerations (FileStatus) |

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

See `Docs/wiki/` for detailed documentation on each topic:

### Conventions/
- [Naming-Conventions.md](Docs/wiki/Conventions/Naming-Conventions.md) - PascalCase, camelCase rules
- [Git-Workflow.md](Docs/wiki/Conventions/Git-Workflow.md) - Conventional commits
- [Import-Organization.md](Docs/wiki/Conventions/Import-Organization.md) - Import ordering
- [File-Organization.md](Docs/wiki/Conventions/File-Organization.md) - Feature grouping

### TCA/
- [Reducer-Patterns.md](Docs/wiki/TCA/Reducer-Patterns.md) - @Reducer macro usage
- [Feature-State-Design.md](Docs/wiki/TCA/Feature-State-Design.md) - State modeling
- [Action-Naming.md](Docs/wiki/TCA/Action-Naming.md) - Action naming conventions
- [Delegation-Pattern.md](Docs/wiki/TCA/Delegation-Pattern.md) - Child→parent communication
- [Effect-Patterns.md](Docs/wiki/TCA/Effect-Patterns.md) - Async effects, streams
- [Dependency-Client-Design.md](Docs/wiki/TCA/Dependency-Client-Design.md) - Client architecture
- [Cancel-ID-Management.md](Docs/wiki/TCA/Cancel-ID-Management.md) - Effect cancellation

### Views/
- [Store-Integration.md](Docs/wiki/Views/Store-Integration.md) - @Bindable usage
- [Binding-Patterns.md](Docs/wiki/Views/Binding-Patterns.md) - Two-way bindings
- [Child-Feature-Scoping.md](Docs/wiki/Views/Child-Feature-Scoping.md) - store.scope()
- [Navigation-Patterns.md](Docs/wiki/Views/Navigation-Patterns.md) - Sheets, covers, links

### Testing/
- [TestStore-Usage.md](Docs/wiki/Testing/TestStore-Usage.md) - TestStoreOf patterns
- [Dependency-Mocking.md](Docs/wiki/Testing/Dependency-Mocking.md) - Test values
- [Swift-Testing-Patterns.md](Docs/wiki/Testing/Swift-Testing-Patterns.md) - @Test macro

### Infrastructure/
- [CoreData-Integration.md](Docs/wiki/Infrastructure/CoreData-Integration.md) - Upsert patterns
- [Keychain-Storage-Valet.md](Docs/wiki/Infrastructure/Keychain-Storage-Valet.md) - Valet usage
- [Push-Notification-Flow.md](Docs/wiki/Infrastructure/Push-Notification-Flow.md) - APNS routing
- [Background-Downloads.md](Docs/wiki/Infrastructure/Background-Downloads.md) - URLSession
- [Environment-Configuration.md](Docs/wiki/Infrastructure/Environment-Configuration.md) - xcconfig

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

See [Dependency-Client-Design.md](Docs/wiki/TCA/Dependency-Client-Design.md) for the full template.

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

## Design System & UI Previews

### Design System Components

When building UI features, **ALWAYS** use the existing design system components in `App/DesignSystem/`:

| Component | Location | Usage |
|-----------|----------|-------|
| `MetadataFormatters` | `DesignSystem/MetadataFormatters.swift` | Format duration, view counts, dates, file sizes |
| `ThumbnailImage` | `DesignSystem/Components/ThumbnailImage.swift` | Async thumbnail with loading/error states |
| `DurationBadge` | `DesignSystem/Components/DurationBadge.swift` | Video duration overlay badge |
| `ExpandableText` | `DesignSystem/Components/ExpandableText.swift` | Collapsible text with clickable URLs |
| `StatItem` | `DesignSystem/Components/StatItem.swift` | Label/value pair for statistics |
| `Theme` | `DesignSystem/Theme.swift` | Colors, fonts, spacing constants |

```swift
// ✅ CORRECT - Use design system components
import SwiftUI

struct MyFileCell: View {
  let file: File

  var body: some View {
    HStack {
      ThumbnailImage(url: file.thumbnailUrl, size: CGSize(width: 120, height: 68))
        .overlay(alignment: .bottomTrailing) {
          if let duration = file.duration {
            DurationBadge(seconds: duration)
          }
        }

      VStack(alignment: .leading) {
        Text(file.title)
        Text(file.author)
          .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4)) // Accent color for author
        Text(MetadataFormatters.formatViewCount(file.viewCount ?? 0))
      }
    }
  }
}

// ❌ FORBIDDEN - Duplicating formatter logic
func formatDuration(_ seconds: Int) -> String {
  // Don't duplicate - use MetadataFormatters.formatDuration()
}
```

### RedesignPreviewCatalog

When adding new UI components or screens, **ALWAYS** add them to `App/DesignSystem/Previews/RedesignPreviewCatalog.swift`:

1. **Add a new case** to `ScreenType` enum
2. **Create a simple preview view** that shows the final design
3. **Show only the current/final state** - no before/after comparisons

```swift
// ✅ CORRECT - Simple preview showing final state
struct FileCellsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FileCellView(file: MockFileData.sample)
                FileCellView(file: MockFileData.shortVideo)
                FileCellView(file: MockFileData.longVideo)
            }
        }
        .background(Color(white: 0.08))
    }
}

// ❌ FORBIDDEN - Before/after comparisons
struct FileCellComparison: View {
    var body: some View {
        VStack {
            Text("BEFORE")
            OldFileCellView(file: sample)
            Text("AFTER")
            NewFileCellView(file: sample)  // Don't do this
        }
    }
}
```

### MockFileData

Use `MockFileData` from `Issue151Previews.swift` for preview sample data:

```swift
// Available mock data
MockFileData.sample      // Standard video with all metadata
MockFileData.shortVideo  // Short video (< 1 min)
MockFileData.longVideo   // Long video (> 1 hour), no thumbnail
```

### Design System Checklist

When implementing a new feature with UI:

- [ ] Check if design system components exist for your needs
- [ ] Create new components in `App/DesignSystem/Components/` if needed
- [ ] Add formatters to `MetadataFormatters` if needed
- [ ] Add preview to `RedesignPreviewCatalog` showing final state
- [ ] Use `MockFileData` for preview sample data
- [ ] Follow accent color convention: `Color(red: 1.0, green: 0.4, blue: 0.4)` for author names

---

## Support Resources

- **TCA Documentation**: https://pointfreeco.github.io/swift-composable-architecture/
- **Valet Documentation**: https://github.com/square/Valet
- **Swift Testing**: https://developer.apple.com/documentation/testing
- **Wiki Conventions**: `Docs/wiki/`
