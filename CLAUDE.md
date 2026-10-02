# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Shared iOS conventions.** The `S` corpus for TCA + SwiftUI projects lives in the
`agent-enforcement` repository at `principles/ios-checks.md`
(`~/Repositories/agent-enforcement/principles/ios-checks.md` on this host). Claude Code receives
those rules through the retrieval hook, so this file does not import them; read that file directly
when a rule ID needs checking. Project-specific conventions stay below.

## Project Overview

This is an iOS offline media downloader app built with The Composable Architecture (TCA). The app connects to an AWS backend, supports Sign in with Apple authentication, push notifications, background downloads, and CoreData persistence.

## Build Commands

**Prerequisite: `design-system-Lifegames` must sit beside this working tree.**
`Packages/OMDFeatures/Package.swift:53` declares `.package(path: "../../../design-system-Lifegames")`,
which resolves to a sibling of the repository root. Check it before any build:

```bash
# from the directory that contains this working tree
ls design-system-Lifegames   # must exist at this level
```

Because the dependency is a path, it binds the WORKTREE, not the repository: a worktree resolves
`../../../design-system-Lifegames` relative to its own location, so each worktree needs its own
sibling (a symlink to one checkout is enough). A worktree parked without that sibling fails before
compiling anything:

```text
error: the package manifest at '<parent>/design-system-Lifegames/Package.swift' cannot be accessed (<parent>/design-system-Lifegames/Package.swift doesn't exist in file system)
```

This is also why the pre-push hook, which runs `xcodebuild build-for-testing`, cannot pass from a
worktree without the sibling. CI clones the design system next to the workspace for the same
reason (`.github/workflows/tests.yml:117` for the test job, `:275` for the release build).

Open the Xcode project and build/run from there:

```bash
open OfflineMediaDownloader.xcodeproj
```

Run tests:

```bash
xcodebuild -project OfflineMediaDownloader.xcodeproj -scheme OfflineMediaDownloader test
```

## Codebase Structure

```text
/ios-OfflineMediaDownloader/
├── App/                              # Thin shell — entry point, AppDelegate, CoreData model
│   ├── OfflineMediaDownloaderApp.swift   # @main entry point
│   ├── AppDelegate.swift                 # Push notifications, background URL sessions
│   ├── Info.plist / App.entitlements      # App metadata
│   ├── Assets.xcassets/                  # App icon, accent color
│   └── OfflineMediaDownloader.xcdatamodeld/ # CoreData model
├── Packages/OMDFeatures/             # SPM package — all application code lives here
│   └── Sources/
│       ├── SharedModels/             # Domain types (File, User, FileStatus, AuthState)
│       ├── DesignSystem/             # Theme, UI components
│       ├── APIClient/                # OpenAPI bridging, AppError, response models
│       ├── ServerClient/             # Networking (depends on APIClient)
│       ├── *Client/                  # Dependency clients (15 such dirs in all)
│       ├── *Feature/                 # TCA @Reducer features (leaf + composite)
│       ├── DownloadBehavior/         # Shared download utilities
│       └── LiveActivityClient/       # Live Activity management
├── APITypes/                         # OpenAPI generated types (Swift Package)
├── ShareExtension/                   # iOS Share Extension for YouTube URLs
├── NotificationServiceExtension/     # Push notification service extension
├── DownloadActivityWidget/           # Live Activity widget extension
├── Scripts/                          # Setup, codegen and validation scripts
├── OfflineMediaDownloaderTests/      # Unit tests (import SPM modules directly)
└── OfflineMediaDownloaderUITests/    # UI tests
```

Every directory under `Packages/OMDFeatures/Sources/` is one SPM library target declared in
`Packages/OMDFeatures/Package.swift`. That mapping, not a remembered list, is the map.

**Client count, derived 2026-10-02.** 15 `*Client` directories under `Sources/`, plus one client
that lives inside a feature target, `MainFeature/UserDefaultsClient.swift`, for 16 clients.
Three of the 15 are named individually in the tree above. Re-derive rather than trust the number:

```bash
ls -1 Packages/OMDFeatures/Sources | grep -c 'Client$'                # 15 client target dirs
git ls-files 'Packages/OMDFeatures/Sources/*Feature/*Client.swift'    # 1 client inside a feature
```

### Organization Convention

- **All application code lives in `Packages/OMDFeatures/Sources/`** — features, clients, models, views
- **`App/` is a thin shell** — entry point, AppDelegate, asset catalog, `Info.plist`, entitlements
  and the CoreData model, nothing else
- **Tests import SPM modules directly** — e.g., `@testable import FileListFeature`, not `@testable import OfflineMediaDownloader`

## Environment Configuration

The app requires environment variables configured in `Development.xcconfig`:

- `MEDIA_DOWNLOADER_API_KEY` - API Gateway key
- `MEDIA_DOWNLOADER_BASE_PATH` - API Gateway invoke URL (note: `//` must be escaped as `$()` in xcconfig)

## TCA Architecture

- Features are `@Reducer` structs with `State`, `Action`, and `body`
- Uses `@DependencyClient` for dependency injection (ServerClient, KeychainClient, AuthenticationClient, etc.)
- Views use `StoreOf<Feature>` with `@Bindable`
- Effects return `.run { }` blocks for async operations
- Uses Valet library for keychain storage

## TCA Patterns Used

**Dependency declaration:**

```swift
@DependencyClient
struct MyClient {
  var someMethod: @Sendable () async throws -> Result
}

extension DependencyValues {
  var myClient: MyClient {
    get { self[MyClient.self] }
    set { self[MyClient.self] = newValue }
  }
}

extension MyClient: DependencyKey {
  static let liveValue = MyClient(...)
}
```

**Feature usage in Reducer:**

```swift
@Dependency(\.myClient) var myClient
```

## Testing

Tests use Swift Testing framework (`import Testing`, `@Test`, `#expect`).

TCA tests use `TestStoreOf<Feature>`:

```swift
@MainActor
@Test func example() async throws {
  let store = TestStoreOf<MyFeature>(initialState: MyFeature.State()) {
    MyFeature()
  }
  await store.send(.someAction) {
    $0.someState = expectedValue
  }
}
```

## Key Dependencies

- TCA: `swift-composable-architecture` 1.22.2+
- Keychain: `Valet` (Secure Enclave support)
- iOS 26+ (Swift 6.2)

## Critical Conventions (DO NOT CHANGE)

These are architectural decisions that MUST NOT be modified without explicit confirmation from the project owner. Past changes to these caused production issues.

### API Key Authentication

**The API key MUST be sent as a query parameter (`?ApiKey=xxx`), NOT as a header.**

- File: `Packages/OMDFeatures/Sources/ServerClient/APIKeyMiddleware.swift`
- The AWS API Gateway Lambda authorizer reads from query string, not headers
- Using `X-API-Key` header will cause 401/403 errors
- Reference: commit `244478b`

```swift
// ✅ CORRECT - Query parameter
request.path = "\(currentPath)?ApiKey=\(apiKey)"

// ❌ WRONG - Header (DO NOT USE)
request.headerFields["X-API-Key"] = apiKey
```

### OpenAPI Spec Sync

The OpenAPI spec is generated from TypeSpec in the backend repo and synced here:

- Source: `aws-cloudformation-media-downloader/docs/api/openapi.yaml`
- Target: `APITypes/Sources/APITypes/openapi.yaml`
- Sync script: `./Scripts/sync-openapi.sh`

Do NOT manually edit the openapi.yaml - fix issues in the backend TypeSpec definitions.

### Parent-Child Data Sharing (Avoid Duplicate API Calls)

When a parent feature fetches data that a child feature also needs, the parent MUST share data with the child via actions rather than both fetching independently.

#### Example: FileListFeature → DefaultFilesFeature

```swift
// ❌ WRONG - Child fetches independently (causes duplicate /files calls)
case .onAppear:
  return .run { send in
    let response = try await serverClient.getFiles(.all)  // DUPLICATE!
    await send(.fileLoaded(response.body?.contents.first))
  }

// ✅ CORRECT - Parent shares data with child
// In parent (FileListFeature):
case let .remoteFilesResponse(.success(response)):
  return .send(.defaultFiles(.parentProvidedFile(response.body?.contents.first)))

// In child (DefaultFilesFeature):
case .onAppear:
  state.isLoadingFile = true
  return .none  // Wait for parent to provide data

case let .parentProvidedFile(file):
  state.isLoadingFile = false
  state.file = file
  return .none
```

This pattern prevents duplicate API calls and keeps data flow unidirectional.
