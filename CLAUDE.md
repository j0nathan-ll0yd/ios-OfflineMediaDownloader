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