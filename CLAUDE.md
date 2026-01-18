# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains an iOS app migration project: migrating from MVVM to The Composable Architecture (TCA). The Composable migration is **partially complete** and needs to be finished.

- **OfflineMediaDownloaderMVVM/** - Reference implementation using MVVM pattern (complete)
- **OfflineMediaDownloaderCompostable/** - Target implementation using TCA (partial)

The app is an offline media downloader that connects to an AWS backend, supports Sign in with Apple authentication, push notifications, background downloads, and CoreData persistence.

## Build Commands

Open the Xcode project and build/run from there:
```bash
open OfflineMediaDownloaderCompostable/OfflineMediaDownloader.xcodeproj
open OfflineMediaDownloaderMVVM/OfflineMediaDownloader.xcodeproj
```

For the TCA Swift Package (MyPackage):
```bash
cd OfflineMediaDownloaderCompostable/MyPackage
swift build
swift test
```

## Environment Configuration

The app requires environment variables configured in `Development.xcconfig`:
- `MEDIA_DOWNLOADER_API_KEY` - API Gateway key
- `MEDIA_DOWNLOADER_BASE_PATH` - API Gateway invoke URL (note: `//` must be escaped as `$()` in xcconfig)

## Architecture Comparison

### MVVM (Reference - Complete)
- ViewModels are `ObservableObject` classes with `@Published` properties
- Uses Combine for reactive data flow and NotificationCenter for event bus
- Direct dependencies on helpers (KeychainHelper, CoreDataHelper, Server)
- Views observe ViewModels via `@ObservedObject`

### TCA (Target - Partial)
- Features are `@Reducer` structs with `State`, `Action`, and `body`
- Uses `@DependencyClient` for dependency injection (ServerClient, KeychainClient, AuthenticationClient)
- Views use `StoreOf<Feature>` with `@Bindable`
- Effects return `.run { }` blocks for async operations
- Uses Valet library for keychain storage (vs custom KeychainHelper in MVVM)

## Migration Status

**Completed in TCA:**
- RootFeature/RootView - App entry point with launch flow
- LoginFeature/LoginView - Sign in with Apple integration
- FileListFeature/FileListView - Basic file list structure
- Dependencies: ServerClient, KeychainClient, AuthenticationClient

**Missing from TCA (exists in MVVM):**
- DiagnosticView/DiagnosticViewModel - Account tab with keychain inspection
- FileCellView/FileCellViewModel - Individual file cell with download/playback
- PendingFileView/PendingFileViewModel - Files being processed
- AVPlayerView - Video playback
- MainView TabView navigation structure
- CoreData integration for local file persistence
- Background download handling
- Push notification device registration flow
- Event bus equivalent for cross-feature communication

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
- iOS 18+ (Swift 6.1)

## Critical Conventions (DO NOT CHANGE)

These are architectural decisions that MUST NOT be modified without explicit confirmation from the project owner. Past changes to these caused production issues.

### API Key Authentication

**The API key MUST be sent as a query parameter (`?ApiKey=xxx`), NOT as a header.**

- File: `App/Dependencies/APIKeyMiddleware.swift`
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

**Example: FileListFeature → DefaultFilesFeature**

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