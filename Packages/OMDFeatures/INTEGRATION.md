# Xcode Integration Guide — OMDFeatures Package

After the SPM package builds independently, follow these steps to wire it into the Xcode project.

## Step 1: Add Local Package Dependency

1. Open `OfflineMediaDownloader.xcodeproj` in Xcode
2. Select the project in the navigator (blue icon, top of tree)
3. Select the **OfflineMediaDownloader** project (not target) in the left panel
4. Go to **Package Dependencies** tab
5. Click **+** → **Add Local...** → navigate to `Packages/OMDFeatures/`
6. Click **Add Package**

## Step 2: Link Package Products to App Target

1. Select the **OfflineMediaDownloader** target
2. Go to **General** tab → **Frameworks, Libraries, and Embedded Content**
3. Click **+** → select `RootFeature` from the OMDFeatures package
4. Also add `SharedModels` and `DesignSystem` if the app shell references them directly

## Step 3: Link Package Products to Widget Target

1. Select the **DownloadActivityWidget** target
2. Go to **General** → **Frameworks, Libraries, and Embedded Content**
3. Add `SharedModels` and `LiveActivityClient` (for shared ActivityAttributes)

## Step 4: Remove Extracted Source Files from App Target

Since `App/` is a Synchronized Folder, the simplest approach:

1. Move the extracted `.swift` files out of `App/` into the package's `Sources/` directories (they're currently copies — the originals are still in `App/`)
2. Or: delete the original files from `App/` subdirectories — Synchronized Folders will automatically remove them from the build

**Files to remove from App/ (they now live in the package):**
- `App/Models/` — File.swift, FileList.swift, User.swift, Device.swift, TokenResponse.swift, LoginResponse.swift, FileResponse.swift, DownloadFileResponse.swift, RegisterDeviceResponse.swift, GeneratedTypes.swift, AppError.swift, PushNotification.swift
- `App/Models/Mappers/` — FileMapper.swift
- `App/Enums/` — FileStatus.swift, AuthState.swift, LoginStatus.swift, RegistrationStatus.swift
- `App/Extensions/` — DateFormatters.swift, String.swift, Environment.swift
- `App/Dependencies/` — ALL 17 files (ServerClient, KeychainClient, etc.)
- `App/Features/` — ALL 11 files
- `App/Views/` — ALL view files
- `App/DesignSystem/` — ALL files
- `App/LiveActivity/` — DownloadActivityAttributes.swift, LiveActivityManager.swift
- `App/Persistence.swift`

**Files that STAY in App/ (thin shell):**
- `App/AppDelegate.swift`
- `App/OfflineMediaDownloaderApp.swift`
- `App/Helpers/TestHelper.swift` (if still needed)

## Step 5: Update App Shell Imports

In `AppDelegate.swift` and `OfflineMediaDownloaderApp.swift`, add:
```swift
import RootFeature
import SharedModels
// ... any other direct imports needed
```

## Step 6: Build & Test

```bash
# Build
xcodebuild build -scheme OfflineMediaDownloader -destination 'generic/platform=iOS Simulator'

# Test
xcodebuild test -scheme OfflineMediaDownloader -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Step 7: Update CI

Add to `.github/workflows/tests.yml`:
```yaml
# SPM package tests (fast, no Xcode project needed)
- name: Run SPM tests
  run: swift test --package-path Packages/OMDFeatures
```
