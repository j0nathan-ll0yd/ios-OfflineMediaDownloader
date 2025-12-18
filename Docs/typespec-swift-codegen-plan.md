# TypeSpec → Swift Codegen Integration Plan

## Goal
Integrate Apple's `swift-openapi-generator` with the iOS Xcode project to automatically generate Swift types from the backend's OpenAPI specification, ensuring frontend/backend type synchronization.

---

## Background

### Current State
- **Backend**: TypeSpec definitions generate `docs/api/openapi.yaml` (OpenAPI 3.0)
- **iOS**: Manual Swift models in `App/Models/` (File, User, Device, etc.)
- **Problem**: Manual models can drift from backend API contract

### Why swift-openapi-generator?
- Official Apple tool, actively maintained
- Supports OpenAPI 3.0, 3.1, 3.2
- Generates type-safe Swift code at build time
- iOS project already uses SPM dependencies (ComposableArchitecture, Valet)

---

## Architecture Decision

### Approach: Local Swift Package with Build Plugin

**Generate types only** (not client) to preserve the existing TCA `@DependencyClient` pattern in `ServerClient.swift`.

```
packages/ios/
├── APITypes/                    # NEW: Local Swift Package
│   ├── Package.swift
│   ├── Sources/APITypes/
│   │   ├── openapi.yaml         # Copied from backend
│   │   └── openapi-generator-config.yaml
│   └── .gitignore
├── App/
│   ├── Models/                  # Migrate to use generated types
│   └── Dependencies/
│       └── ServerClient.swift   # Keeps TCA pattern, uses generated types
└── OfflineMediaDownloader.xcodeproj
```

**Why Local Package?**
1. Clean separation of generated vs hand-written code
2. Build plugin runs in package context
3. Main app imports `APITypes` module
4. Easy to regenerate by updating `openapi.yaml`

---

## Implementation Steps

### Step 1: Create Local Swift Package

**Create**: `packages/ios/APITypes/Package.swift`

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "APITypes",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "APITypes", targets: ["APITypes"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "APITypes",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        )
    ]
)
```

### Step 2: Configure Generator

**Create**: `packages/ios/APITypes/Sources/APITypes/openapi-generator-config.yaml`

```yaml
generate:
  - types              # Only generate types, not client
accessModifier: public
```

### Step 3: Copy OpenAPI Spec

**Copy**: `packages/backend/docs/api/openapi.yaml` → `packages/ios/APITypes/Sources/APITypes/openapi.yaml`

**Add script**: `packages/ios/Scripts/sync-openapi.sh`

```bash
#!/bin/bash
# Sync OpenAPI spec from backend to iOS
cp ../backend/docs/api/openapi.yaml APITypes/Sources/APITypes/openapi.yaml
echo "OpenAPI spec synced"
```

### Step 4: Add Package to Xcode Project

1. Open `OfflineMediaDownloader.xcodeproj`
2. File → Add Package Dependencies → Add Local → Select `APITypes/`
3. Add `APITypes` library to app target

### Step 5: Build and Trust Plugin

1. Build project (Cmd+B)
2. Click "Trust & Enable" when prompted for OpenAPIGenerator plugin
3. Rebuild - generated types now available

### Step 6: Create Type Aliases for Migration

**Create**: `packages/ios/App/Models/GeneratedTypes.swift`

```swift
import APITypes

// Type aliases for gradual migration
// Maps generated types to existing names for compatibility

public typealias APIFile = Components.Schemas.Models_File
public typealias APIFileStatus = Components.Schemas.Models_FileStatus
public typealias APIFileListResponse = Components.Schemas.Models_FileListResponse
public typealias APIDevice = Components.Schemas.Models_Device
public typealias APIDeviceRegistrationRequest = Components.Schemas.Models_DeviceRegistrationRequest
public typealias APIDeviceRegistrationResponse = Components.Schemas.Models_DeviceRegistrationResponse
public typealias APIUserLogin = Components.Schemas.Models_UserLogin
public typealias APIUserLoginResponse = Components.Schemas.Models_UserLoginResponse
public typealias APIUserRegistration = Components.Schemas.Models_UserRegistration
public typealias APIUserRegistrationResponse = Components.Schemas.Models_UserRegistrationResponse
public typealias APIFeedlyWebhook = Components.Schemas.Models_FeedlyWebhook
public typealias APIWebhookResponse = Components.Schemas.Models_WebhookResponse
```

### Step 7: Update ServerClient to Use Generated Types

**Modify**: `packages/ios/App/Dependencies/ServerClient.swift`

```swift
import APITypes

// Update response types to use generated types
var getFiles: @Sendable () async throws -> APIFileListResponse
var registerDevice: @Sendable (_ request: APIDeviceRegistrationRequest) async throws -> APIDeviceRegistrationResponse
// ... etc
```

### Step 8: Migrate File Model

The existing `File.swift` has CoreData mapping that generated types won't have. Two options:

**Option A**: Keep `File.swift` as domain model, convert from generated type
```swift
extension File {
    init(from api: APIFile) {
        self.fileId = api.fileId
        self.key = api.key ?? ""
        self.status = api.status.map { FileStatus(rawValue: $0.rawValue) } ?? nil
        // ... map other fields
    }
}
```

**Option B**: Add CoreData mapping as extension on generated type (more complex)

**Recommendation**: Option A - cleaner separation between API and domain layers

### Step 9: Update Tests

Update test mocks to use generated types where applicable.

---

## File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `APITypes/Package.swift` | Local Swift Package definition |
| `APITypes/Sources/APITypes/openapi.yaml` | OpenAPI spec (copied from backend) |
| `APITypes/Sources/APITypes/openapi-generator-config.yaml` | Generator config |
| `APITypes/.gitignore` | Ignore `.build/` directory |
| `Scripts/sync-openapi.sh` | Script to sync OpenAPI spec |
| `App/Models/GeneratedTypes.swift` | Type aliases for migration |

### Modified Files

| File | Changes |
|------|---------|
| `OfflineMediaDownloader.xcodeproj` | Add APITypes package dependency |
| `App/Dependencies/ServerClient.swift` | Use generated types for API requests/responses |
| `App/Models/File.swift` | Add initializer from generated type |
| `App/Models/FileResponse.swift` | Potentially remove (use generated type) |
| `App/Models/LoginResponse.swift` | Potentially remove (use generated type) |

### Files to Potentially Remove

After full migration, these manual models become redundant:
- `RegisterDeviceResponse.swift`
- `DownloadFileResponse.swift`
- Portions of other response models

---

## Success Criteria

1. Local `APITypes` package builds successfully
2. Generated types are accessible in main app
3. ServerClient uses generated types for at least one endpoint
4. Xcode build succeeds
5. Unit tests pass
6. App runs and can fetch files from API

---

## Future Enhancements

### Automated OpenAPI Sync
Add GitHub Action to:
1. Detect changes to `docs/api/openapi.yaml` in backend
2. Open PR in iOS repo with updated spec
3. Or use git submodule/subtree for shared spec

### Generate Client Too
Once comfortable with generated types, could also generate the Client:
```yaml
generate:
  - types
  - client
```
This would replace much of `ServerClient.swift` with generated code.

### Strict Mode
Enable strict OpenAPI validation:
```yaml
featureFlags:
  - strictOpenAPIValidation
```

---

## Notes

- **Plugin Trust**: All developers need to click "Trust & Enable" for the build plugin on first build
- **Generated Code Location**: Generated files are in `.build/plugins/` (not committed)
- **iOS 26 Requirement**: The project targets iOS 26+, which is compatible with latest swift-openapi-generator
