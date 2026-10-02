# Offline Media Downloader

A modern iOS app for downloading and managing offline media files, built with The Composable Architecture (TCA).

## Overview

This app serves as the companion iOS client for the [AWS media downloader backend](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader). It allows users to download media files (e.g., YouTube videos) to their device for offline viewing.

## Architecture

- **iOS 26.0** deployment target, **Swift 6.2**
- **The Composable Architecture (TCA)** 1.22.2+
- **Valet** for Keychain/Secure Enclave storage
- **CoreData** for local file persistence

### Feature Hierarchy

```text
App Entry Point (OfflineMediaDownloaderApp)
└── RootFeature (launch, auth routing)
    ├── LoginFeature (Sign in with Apple)
    ├── DownloadTrackingFeature (background download progress)
    ├── DiagnosticFeature (keychain inspection; presented, DEBUG builds only)
    └── MainFeature (two tabs: files, account)
        ├── FileListFeature
        │   ├── FileCellFeature[] (per-file downloads, playback)
        │   ├── FileDetailFeature (presented)
        │   └── DefaultFilesFeature
        ├── ProfileFeature
        ├── LoginFeature (accountLogin, account tab)
        └── ActiveDownloadsFeature
```

Read off the reducer bodies, not from memory: `RootFeature.swift:107,110,391,394`,
`MainFeature.swift:61-76`, `FileListFeature.swift:639-645`. `RootFeature` scopes `login`,
`downloadTracking` and `main`, and attaches `diagnostic` through `.ifLet` inside `#if DEBUG`.

Four further reducers live inside a parent target rather than in a target of their own, and are
reached by presentation instead of a `Scope`:

- `LoginFeature/EmailLoginFeature.swift` (`LoginFeature.swift:55,228`)
- `MainFeature/DownloadSettingsFeature.swift`, `MainFeature/EditProfileFeature.swift` and
  `MainFeature/NotificationsFeature.swift` (`MainFeature.swift:54-58`)

## Key Features

- **Sign in with Apple** authentication
- **Push notifications** for new file availability
- **Background downloads** via URLSession
- **Offline support** with CoreData persistence
- **Video playback** with AVKit

## Project Structure

```text
├── App/                              # Thin app shell: 2 Swift files, assets, CoreData model
├── Packages/OMDFeatures/             # SPM package — every feature, client and view
│   ├── Package.swift
│   ├── Sources/                      # One directory per library target
│   └── Tests/                        # Package test targets
├── APITypes/                         # SPM package — types generated from the OpenAPI spec
├── ShareExtension/                   # Share Extension: accepts YouTube URLs
├── NotificationServiceExtension/     # Push notification service extension
├── DownloadActivityWidget/           # Live Activity widget extension
├── Scripts/                          # Setup, codegen and validation scripts
├── Docs/wiki/                        # Architecture documentation
├── OfflineMediaDownloader.xcodeproj
├── OfflineMediaDownloaderTests/      # App-target unit tests (the suite CI runs)
└── OfflineMediaDownloaderUITests/
```

Two rules make the layout predictable:

- **Feature code lives in `Packages/OMDFeatures/Sources/`.** Every directory there is one SPM
  library target, declared in `Packages/OMDFeatures/Package.swift`. Targets carry a `*Feature`,
  `*Client` or domain suffix.
- **`App/` is a shell.** It holds `OfflineMediaDownloaderApp.swift`, `AppDelegate.swift`, the
  asset catalog, `Info.plist`, the entitlements and the CoreData model. No feature reducers and
  no feature views: its only view is the private `AppContentView` wrapper around `RootView`.

`CLAUDE.md` carries the annotated, target-by-target version of this map and is the file to trust
when the two disagree.

## Getting Started

### Prerequisites

1. **Xcode 26.** The app builds against the iOS 26 SDK
   (`IPHONEOS_DEPLOYMENT_TARGET = 26.0` in `OfflineMediaDownloader.xcodeproj/project.pbxproj`) and
   both package manifests declare `swift-tools-version: 6.2`. CI builds and tests on the
   `xcode-26` self-hosted macOS lane (`.github/workflows/tests.yml:96,110,270`). Xcode 16 cannot
   build this project.
2. **`design-system-Lifegames` cloned as a sibling of this repository.** This is a hard build
   requirement, not an optional extra: `Packages/OMDFeatures/Package.swift:53` declares
   `.package(path: "../../../design-system-Lifegames")`, which resolves to a sibling of the
   repository root. Verify it:

   ```bash
   # from the directory that contains this repository
   ls design-system-Lifegames   # must exist at this level
   ```

   The dependency is a path, so it binds the **working tree**, not the repository. A git worktree
   resolves `../../../design-system-Lifegames` relative to its own location, so every worktree
   needs its own sibling (a symlink to one checkout is enough). Without it, SwiftPM stops before
   it compiles anything:

   ```text
   error: the package manifest at '<parent>/design-system-Lifegames/Package.swift' cannot be accessed (<parent>/design-system-Lifegames/Package.swift doesn't exist in file system)
   ```

   CI satisfies the same constraint by cloning the design system next to the workspace
   (`.github/workflows/tests.yml:117` for the test job, `:275` for the release build).

3. An Apple Developer account (for push notifications and Sign in with Apple)

### Backend Setup

1. [Install](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#installation) the backend source code
2. [Deploy](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#deployment) the application to your AWS account

### Environment Configuration

1. Copy `Development.xcconfig.example` to `Development.xcconfig`
2. Configure the following variables:

| Variable                     | Description            |
| ---------------------------- | ---------------------- |
| `MEDIA_DOWNLOADER_API_KEY`   | API Gateway iOSAppKey  |
| `MEDIA_DOWNLOADER_BASE_PATH` | API Gateway invoke URL |

> **Note**: Use `$()` to escape `//` in URLs (e.g., `https:$()/$()/example.com`)

### Finding Your AWS Values

**API Key**: AWS Console → API Gateway → API Keys → iOSAppKey → Show

**Base Path**: AWS Console → API Gateway → Dashboard → Invocation URL

## Documentation

Start with [CLAUDE.md](CLAUDE.md): it holds the current codebase map, the build constraints and
the conventions that must not change.

Pattern documentation lives in [Docs/wiki/](Docs/wiki/):

- [TCA Patterns](Docs/wiki/TCA/) - Reducer, dependency, and effect patterns
- [View Conventions](Docs/wiki/Views/) - SwiftUI + TCA integration
- [Testing](Docs/wiki/Testing/) - TestStore and dependency mocking
- [Infrastructure](Docs/wiki/Infrastructure/) - CoreData, Keychain, push notifications

Treat the file paths in those pages as stale. `Docs/wiki/` was last updated in commit `efefcdb`
(2026-01-16); the SPM modularization that moved every source file landed later, in `d44342e`
(2026-04-06). The patterns still hold; the locations do not.

## License

Private repository - All rights reserved.
