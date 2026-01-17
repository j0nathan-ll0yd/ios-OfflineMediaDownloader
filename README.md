# Offline Media Downloader

A modern iOS app for downloading and managing offline media files, built with The Composable Architecture (TCA).

## Overview

This app serves as the companion iOS client for the [AWS media downloader backend](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader). It allows users to download media files (e.g., YouTube videos) to their device for offline viewing.

## Architecture

- **iOS 26+**, **Swift 6.1**
- **The Composable Architecture (TCA)** 1.22.2+
- **Valet** for Keychain/Secure Enclave storage
- **CoreData** for local file persistence

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

## Key Features

- **Sign in with Apple** authentication
- **Push notifications** for new file availability
- **Background downloads** via URLSession
- **Offline support** with CoreData persistence
- **Video playback** with AVKit

## Project Structure

```
├── AGENTS.md                    # AI assistant context
├── App/
│   ├── Features/                # TCA Reducers
│   ├── Views/                   # SwiftUI Views
│   ├── Dependencies/            # Dependency Clients
│   ├── Models/                  # Data models
│   └── Extensions/              # Swift extensions
├── Docs/
│   └── wiki/                    # Architecture documentation
├── OfflineMediaDownloader.xcodeproj
├── OfflineMediaDownloaderTests/
└── OfflineMediaDownloaderUITests/
```

## Getting Started

### Prerequisites

1. Xcode 16+
2. macOS 15+
3. An Apple Developer account (for push notifications and Sign in with Apple)

### Backend Setup

1. [Install](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#installation) the backend source code
2. [Deploy](https://github.com/j0nathan-ll0yd/aws-cloudformation-media-downloader#deployment) the application to your AWS account

### Environment Configuration

1. Copy `Development.xcconfig.example` to `Development.xcconfig`
2. Configure the following variables:

| Variable | Description |
|----------|-------------|
| `MEDIA_DOWNLOADER_API_KEY` | API Gateway iOSAppKey |
| `MEDIA_DOWNLOADER_BASE_PATH` | API Gateway invoke URL |

> **Note**: Use `$()` to escape `//` in URLs (e.g., `https:$()/$()/example.com`)

### Finding Your AWS Values

**API Key**: AWS Console → API Gateway → API Keys → iOSAppKey → Show

**Base Path**: AWS Console → API Gateway → Dashboard → Invocation URL

## Documentation

Comprehensive architecture documentation is available in [Docs/wiki/](Docs/wiki/):

- [TCA Patterns](Docs/wiki/TCA/) - Reducer, dependency, and effect patterns
- [View Conventions](Docs/wiki/Views/) - SwiftUI + TCA integration
- [Testing](Docs/wiki/Testing/) - TestStore and dependency mocking
- [Infrastructure](Docs/wiki/Infrastructure/) - CoreData, Keychain, push notifications

## License

Private repository - All rights reserved.
