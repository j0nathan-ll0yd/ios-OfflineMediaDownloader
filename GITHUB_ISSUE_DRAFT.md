# Comprehensive Refactor & Modernization Plan (Phases 1-5)

**Type:** Epic / Technical Debt
**Priority:** High
**Status:** Ready for Development

## Overview

This issue outlines a critical stability and modernization roadmap for `ios-OfflineMediaDownloader`. The goal is to address data integrity risks in background downloads and Core Data persistence, while simultaneously migrating to the type-safe OpenAPI client and standardizing UI patterns.

## Phase 1: Critical Stability Fixes

### 1.1 Background Download Continuity
**Risk:** Currently, if the system terminates the app while a download is in progress, the completion callbacks are lost. Upon relaunch, the app has no way to know the download finished, leading to "zombie" files and UI desynchronization.

**Implementation Steps:**
1.  **Modify `DownloadManager` (Actor):**
    -   Add a property to store the system completion handler:
        ```swift
        private var backgroundCompletionHandler: (() -> Void)?
        ```
    -   Add a method to capture it:
        ```swift
        func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
            self.backgroundCompletionHandler = handler
        }
        ```
    -   Update `urlSessionDidFinishEvents(forBackgroundURLSession:)`:
        ```swift
        nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            Task {
                await self.callCompletionHandler()
            }
        }
        
        // Inside actor
        private func callCompletionHandler() {
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
        ```

2.  **Update `AppDelegate.swift`:**
    -   Implement the missing delegate method.
    -   **Crucial:** Ensure the `DownloadManager` (and its session) is initialized *before* returning from this method.
    ```swift
    func application(
      _ application: UIApplication,
      handleEventsForBackgroundURLSession identifier: String,
      completionHandler: @escaping () -> Void
    ) {
        // 1. Re-initialize DownloadManager if needed (it's a singleton, so accessing .shared is enough)
        // 2. Pass the handler
        Task {
            await DownloadManager.shared.setBackgroundCompletionHandler(completionHandler)
        }
    }
    ```

### 1.2 Core Data Concurrency (Performance)
**Risk:** `CoreDataClient.cacheFiles` uses `viewContext.perform`. When syncing hundreds of files, this blocks the main thread, causing scroll stutter and dropped frames.

**Implementation Steps:**
1.  **Modify `CoreDataClient.liveValue`:**
    -   Stop using `PersistenceController.shared.container.viewContext` for writes.
    -   Create a background context for heavy operations:
    ```swift
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    ```
2.  **Implement Batch Inserts:**
    -   Refactor `cacheFiles` to use `NSBatchInsertRequest` for better performance if possible, or simple background iteration.
    ```swift
    cacheFiles: { files in
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
             // Logic to update/insert files
             // MUST use file IDs to check existence efficiently
             try context.save()
        }
    }
    ```
3.  **Thread Safety:** Ensure `FileEntity` objects are not passed between contexts. Pass plain struct `File` objects into the closure, and mapped back out.

## Phase 2: Networking Modernization

**Goal:** Remove manual `URLRequest` construction in `ServerClient.swift` and use the generated `APIProtocol`.

**Implementation Steps:**
1.  **Create `AuthenticationMiddleware`:**
    -   Implement `ClientMiddleware` from `OpenAPIRuntime`.
    -   Inject `KeychainClient` dependency.
    -   Intercept requests and add `Authorization: Bearer <token>`.
    ```swift
    struct AuthenticationMiddleware: ClientMiddleware {
        let keychainClient: KeychainClient
        func intercept(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String, next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
            var request = request
            if let token = try? await keychainClient.getJwtToken() {
                request.headerFields[.authorization] = "Bearer \(token)"
            }
            return try await next(request, body, baseURL)
        }
    }
    ```
2.  **Refactor `ServerClient.liveValue`:**
    -   Initialize the generated client:
    ```swift
    let client = Client(
        serverURL: try! Servers.server1(),
        transport: URLSessionTransport(),
        middlewares: [AuthenticationMiddleware(...)]
    )
    ```
    -   Replace manual calls with `try await client.getFiles()`.
    -   Map the generated `Components.Schemas.File` to our domain `File`.

## Phase 3: Architecture & Refactoring

### 3.1 Model Separation
**Goal:** Decouple the monolithic `File` struct.

**Implementation Steps:**
1.  **Create `App/Models/Mappers/FileMapper.swift`:**
    -   Move the `init(from api: APIFile)` and `toEntity` logic here.
    -   Keep `App/Models/File.swift` as a pure Swift struct (Domain Model).
2.  **Refactor `File.swift`:**
    -   Remove `Codable` compliance if only used for internal passing (or keep specific decoding for `CoreData` if manual).
    -   Remove `import CoreData` and `import APITypes` from `File.swift`.

### 3.2 List Performance
**Goal:** Optimize `FileListView` for large datasets.

**Implementation Steps:**
1.  **Switch to `List`:**
    -   If not already, ensure `List` is used instead of `ScrollView + LazyVStack` for better recycling of complex cells.
2.  **Optimize `ForEachStore`:**
    -   Ensure `FileCellFeature` state is `@ObservableState`.
    -   Verify that actions sent from cells are `id`-based in the parent reducer to avoid traversing the entire array.

## Phase 4: UI Enhancements

### 4.1 Native Video Player
**Goal:** Replace custom `VideoPlayerView` with `AVPlayerViewController`.

**Implementation Steps:**
1.  **Create Wrapper:**
    ```swift
    struct MediaPlayerView: UIViewControllerRepresentable {
        let url: URL
        func makeUIViewController(context: Context) -> AVPlayerViewController {
            let controller = AVPlayerViewController()
            let player = AVPlayer(url: url)
            controller.player = player
            player.play()
            return controller
        }
        // ... updateUIViewController
    }
    ```
2.  **Integrate:**
    -   Replace the manual `VideoPlayer` in `FileListView` with this wrapper.
    -   Enable PiP capabilities in `AVAudioSession` (already partially done in `AppDelegate`).

## Phase 5: Testing & Tooling

### 5.1 Test Coverage
**Implementation Steps:**
1.  **Mock URLSession:**
    -   Create a `URLProtocol` mock to test `DownloadClient` logic without hitting the network.
    -   Verify that `downloadFile` yields correct progress percentages.
2.  **Snapshot Tests:**
    -   Add `swift-snapshot-testing` dependency.
    -   Create snapshots for `FileCellView` (downloaded, downloading, pending states).

### 5.2 Scripts & Hooks
**Implementation Steps:**
1.  **Pre-commit Hook:**
    -   Update `.githooks/pre-push` or create `pre-commit` to run:
        -   `Scripts/validate-tca-patterns.sh`
        -   `swift test`

## Acceptance Criteria
- [ ] `AppDelegate` handles background session events; downloads resume/complete after app termination.
- [ ] Core Data writes happen on a background context; UI does not stutter during sync.
- [ ] `ServerClient` uses `swift-openapi-generator` client; manual `URLRequest` code is removed.
- [ ] `File` model is decoupled from `CoreData` and `APITypes` imports.
- [ ] Video playback uses `AVPlayerViewController`.
- [ ] Unit tests pass, including new `DownloadClient` tests.
