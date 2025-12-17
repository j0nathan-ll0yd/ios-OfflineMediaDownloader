# File Organization

## Quick Reference
- **When to use**: When adding new files to the project
- **Enforcement**: Required
- **Impact if violated**: Medium - Project navigation difficulty

---

## Directory Structure

```
OfflineMediaDownloaderCompostable/
├── App/
│   ├── Features/           # Standalone TCA reducers
│   │   ├── MainFeature.swift
│   │   └── DiagnosticFeature.swift
│   │
│   ├── Views/              # Views + co-located reducers
│   │   ├── RootView.swift          # Contains RootFeature
│   │   ├── LoginView.swift         # Contains LoginFeature
│   │   ├── FileListView.swift      # Contains FileListFeature, FileCellFeature
│   │   ├── DiagnosticView.swift    # Uses DiagnosticFeature
│   │   ├── LogoView.swift          # Presentational only
│   │   └── ErrorMessageView.swift  # Presentational only
│   │
│   ├── Dependencies/       # TCA dependency clients
│   │   ├── ServerClient.swift
│   │   ├── KeychainClient.swift
│   │   ├── AuthenticationClient.swift
│   │   ├── CoreDataClient.swift
│   │   ├── DownloadClient.swift
│   │   └── FileClient.swift
│   │
│   ├── Models/             # Data models
│   │   ├── File.swift
│   │   ├── UserData.swift
│   │   ├── FileResponse.swift
│   │   ├── LoginResponse.swift
│   │   └── PushNotification.swift
│   │
│   └── Extensions/         # Swift extensions
│       └── String.swift
│
├── MyPackage/              # Swift Package for shared features
│   ├── Package.swift
│   ├── Sources/
│   └── Tests/
│
├── Constants.swift         # App-wide constants
├── AppDelegate.swift       # Push notifications, background
└── OfflineMediaDownloaderApp.swift  # @main entry point
```

---

## Placement Rules

### Features
Place TCA reducers based on their relationship with views:

| Scenario | Location | Example |
|----------|----------|---------|
| Feature + View tightly coupled | `Views/FeatureView.swift` | FileListFeature in FileListView.swift |
| Feature used by multiple views | `Features/Feature.swift` | MainFeature.swift |
| Feature is container only | `Features/Feature.swift` | MainFeature.swift |

### Co-located Features
When a feature and view are tightly coupled, keep them in the same file:

```swift
// FileListView.swift

// MARK: - FileCellFeature
@Reducer
struct FileCellFeature {
  // ...
}

struct FileCellView: View {
  // ...
}

// MARK: - FileListFeature
@Reducer
struct FileListFeature {
  // ...
}

struct FileListView: View {
  // ...
}
```

### Dependency Clients
One file per client in `App/Dependencies/`:
```
Dependencies/
├── ServerClient.swift      # HTTP API
├── KeychainClient.swift    # Valet storage
├── AuthenticationClient.swift  # Apple ID
├── CoreDataClient.swift    # Persistence
├── DownloadClient.swift    # URLSession
└── FileClient.swift        # File system
```

### Models
Group related models together or split into individual files:

```
Models/
├── File.swift              # Core file model
├── UserData.swift          # User identity
├── FileResponse.swift      # API responses
├── LoginResponse.swift     # Auth responses
└── PushNotification.swift  # Push payload types
```

### Extensions
Name extensions by the type being extended:
```
Extensions/
├── String.swift            # String+youtubeID
├── DateFormatter.swift     # DateFormatter+iso8601
└── Data.swift              # Data+prettyPrint
```

Or use more specific names:
```
Extensions/
├── String+YouTube.swift
├── DateFormatter+ISO8601.swift
└── Data+JSON.swift
```

---

## File Content Organization

Within a Swift file, use this order:

```swift
// 1. Imports
import SwiftUI
import ComposableArchitecture

// 2. Feature reducer (if co-located)
@Reducer
struct MyFeature {
  // ...
}

// 3. Main view
struct MyView: View {
  // ...
}

// 4. Supporting views (private if possible)
private struct SupportingView: View {
  // ...
}

// 5. Helper functions
private func formatSize(_ bytes: Int) -> String {
  // ...
}

// 6. Previews
#Preview {
  MyView(store: Store(...))
}
```

---

## When to Create New Files

### Create a new file when:
- Adding a new dependency client
- Adding a new standalone feature
- Adding a new model type
- The current file exceeds ~500 lines

### Keep in same file when:
- Feature and view are tightly coupled
- Helper views are only used by one parent
- Private helper functions

---

## Rationale

- **Discoverability**: Predictable locations for features, views, clients
- **Scalability**: Clear separation as project grows
- **Code reviews**: Smaller, focused files are easier to review
- **Navigation**: Xcode's file navigator reflects logical structure

---

## Related Patterns
- [Naming-Conventions.md](Naming-Conventions.md)
- [Import-Organization.md](Import-Organization.md)
- [Reducer-Patterns.md](../TCA/Reducer-Patterns.md)
