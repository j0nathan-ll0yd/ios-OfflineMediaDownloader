# Push Notification Flow

## Quick Reference
- **When to use**: Receiving and routing push notifications
- **Enforcement**: Required for real-time updates
- **Impact if violated**: High - Missed notifications

---

## Overview

Push notifications flow through:
1. AppDelegate receives raw notification
2. Parses payload into typed enum
3. Routes to RootFeature
4. RootFeature processes and forwards to appropriate child

---

## Notification Types

```swift
enum PushNotificationType: Equatable {
  case metadata(File)           // New file metadata available
  case downloadReady(fileId: String, url: URL)  // Download URL ready
  case unknown
}
```

---

## AppDelegate Setup

### Registration
```swift
func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge]
  ) { granted, error in
    if granted {
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }
  return true
}
```

### Device Token Receipt
```swift
func application(
  _ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
  let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
  print("📱 Device token: \(token)")

  // Store token and register with backend
  Task {
    @Dependency(\.serverClient) var serverClient
    @Dependency(\.keychainClient) var keychainClient

    let response = try await serverClient.registerDevice(token: token)
    if let endpointArn = response.body?.endpointArn {
      try await keychainClient.setDeviceData(DeviceData(endpointArn: endpointArn))
    }
  }
}
```

### Notification Receipt
```swift
func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  print("📬 Push notification received")

  // Parse and route to store
  if let store = appStore {
    store.send(.receivedPushNotification(userInfo))
  }

  completionHandler(.newData)
}
```

---

## Payload Parsing

### Metadata Notification
```json
{
  "aps": { "content-available": 1 },
  "type": "metadata",
  "file": {
    "fileId": "abc123",
    "key": "video.mp4",
    "title": "My Video",
    "publishDate": "2024-01-15",
    "size": 1000000
  }
}
```

### Download Ready Notification
```json
{
  "aps": { "content-available": 1 },
  "type": "downloadReady",
  "fileId": "abc123",
  "url": "https://cdn.example.com/video.mp4"
}
```

### Parsing Function
```swift
func parsePushNotification(_ userInfo: [AnyHashable: Any]) -> PushNotificationType {
  guard let type = userInfo["type"] as? String else {
    return .unknown
  }

  switch type {
  case "metadata":
    if let fileData = userInfo["file"] as? [String: Any],
       let file = try? JSONDecoder().decode(File.self, from: JSONSerialization.data(withJSONObject: fileData)) {
      return .metadata(file)
    }

  case "downloadReady":
    if let fileId = userInfo["fileId"] as? String,
       let urlString = userInfo["url"] as? String,
       let url = URL(string: urlString) {
      return .downloadReady(fileId: fileId, url: url)
    }

  default:
    break
  }

  return .unknown
}
```

---

## RootFeature Handling

### Action Definition
```swift
enum Action {
  case receivedPushNotification([AnyHashable: Any])
  case processedNotification(PushNotificationType)
  // ...
}
```

### Processing Logic
```swift
case let .receivedPushNotification(userInfo):
  let notification = parsePushNotification(userInfo)
  return .send(.processedNotification(notification))

case let .processedNotification(notification):
  switch notification {
  case let .metadata(file):
    // Save to CoreData and forward to FileList
    return .run { send in
      try await coreDataClient.cacheFile(file)
      await send(.main(.fileList(.fileAddedFromPush(file))))
    }

  case let .downloadReady(fileId, url):
    // Update file URL and trigger refresh
    return .run { send in
      try await coreDataClient.updateFileUrl(fileId: fileId, url: url)
      await send(.main(.fileList(.updateFileUrl(fileId: fileId, url: url))))
    }

  case .unknown:
    return .none
  }
```

---

## FileListFeature Actions

```swift
enum Action {
  // Push notification actions
  case fileAddedFromPush(File)
  case updateFileUrl(fileId: String, url: URL)
  case refreshFileState(String)
  // ...
}
```

### Handling in Reducer
```swift
case let .fileAddedFromPush(file):
  // Add or update file in the list
  if var existing = state.files[id: file.fileId] {
    existing.file = file
    state.files[id: file.fileId] = existing
  } else {
    state.files.append(FileCellFeature.State(file: file))
  }

  // Sort by date
  state.files.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }

  // Remove from pending
  state.pendingFileIds.removeAll { $0 == file.fileId }
  return .none

case let .updateFileUrl(fileId, url):
  if var fileState = state.files[id: fileId] {
    fileState.file.url = url
    state.files[id: fileId] = fileState
  }
  return .none
```

---

## Background App Refresh

For silent notifications (content-available: 1):

```swift
// AppDelegate or SceneDelegate
func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  // Process notification
  processNotification(userInfo)

  // Tell iOS if new data was fetched
  completionHandler(.newData)
}
```

---

## Testing Push Notifications

### Simulating in Tests
```swift
@Test func handlesMetadataNotification() async throws {
  let testFile = File(fileId: "test", key: "video.mp4", publishDate: Date(), size: 1000, url: nil)

  let store = TestStoreOf<RootFeature>(
    initialState: RootFeature.State()
  ) {
    RootFeature()
  } withDependencies: {
    $0.coreDataClient.cacheFile = { _ in }
  }

  await store.send(.processedNotification(.metadata(testFile)))

  await store.receive(\.main.fileList.fileAddedFromPush) {
    // Verify state update
  }
}
```

### Simulator Testing
Use Xcode to drag .apns files onto simulator, or:

```bash
xcrun simctl push booted com.yourapp.bundle notification.apns
```

---

## Error Handling

```swift
case let .processedNotification(notification):
  switch notification {
  case let .metadata(file):
    return .run { send in
      do {
        try await coreDataClient.cacheFile(file)
        await send(.main(.fileList(.fileAddedFromPush(file))))
      } catch {
        print("❌ Failed to cache file from push: \(error)")
      }
    }
  // ...
  }
```

---

## Anti-Patterns

### Don't process notifications in AppDelegate
```swift
// ❌ Wrong - Business logic in AppDelegate
func didReceiveRemoteNotification(...) {
  let file = parseFile(userInfo)
  CoreDataHelper.saveFile(file)  // Direct access
}

// ✅ Correct - Route to TCA
func didReceiveRemoteNotification(...) {
  store.send(.receivedPushNotification(userInfo))
}
```

### Don't ignore unknown notifications
```swift
// ❌ Wrong - Silent failure
guard let type = userInfo["type"] as? String else { return }

// ✅ Correct - Log and handle gracefully
case .unknown:
  print("⚠️ Unknown push notification type")
  return .none
```

---

## Rationale

- **Centralized routing**: All notifications flow through RootFeature
- **Testability**: Notification handling can be unit tested
- **Type safety**: Typed enum prevents runtime errors

---

## Related Patterns
- [Reducer-Patterns.md](../TCA/Reducer-Patterns.md)
- [Delegation-Pattern.md](../TCA/Delegation-Pattern.md)
