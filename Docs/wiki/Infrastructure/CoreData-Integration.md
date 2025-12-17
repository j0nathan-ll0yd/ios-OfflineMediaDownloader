# CoreData Integration

## Quick Reference
- **When to use**: Persisting file metadata locally
- **Enforcement**: Required for offline support
- **Impact if violated**: High - Data loss on app restart

---

## The Rule

Use CoreDataClient dependency for all persistence operations. Never access CoreData directly from reducers.

---

## CoreDataClient Interface

```swift
@DependencyClient
struct CoreDataClient {
  var getFiles: @Sendable () async throws -> [File]
  var getFile: @Sendable (_ fileId: String) async throws -> File?
  var cacheFiles: @Sendable (_ files: [File]) async throws -> Void
  var cacheFile: @Sendable (_ file: File) async throws -> Void
  var updateFileUrl: @Sendable (_ fileId: String, _ url: URL) async throws -> Void
  var deleteFile: @Sendable (_ file: File) async throws -> Void
  var truncateFiles: @Sendable () async throws -> Void
  var saveContext: @Sendable () async throws -> Void
}
```

---

## Entity Schema

### File Entity
```
File
├── fileId: String (optional)
├── key: String (optional, unique constraint)
├── title: String (optional)
├── authorName: String (optional)
├── publishDate: Date (optional)
├── size: Int64 (optional)
└── url: URI (optional)
```

---

## Implementation Patterns

### Upsert Pattern
Insert new records or update existing ones:

```swift
cacheFile: { file in
  let context = persistentContainer.viewContext

  await context.perform {
    // Find existing or create new
    let request = NSFetchRequest<FileMO>(entityName: "File")
    request.predicate = NSPredicate(format: "fileId == %@", file.fileId)

    let existing = try? context.fetch(request).first

    let entity = existing ?? FileMO(context: context)
    entity.fileId = file.fileId
    entity.key = file.key
    entity.title = file.title
    entity.authorName = file.authorName
    entity.publishDate = file.publishDate
    entity.size = Int64(file.size ?? 0)
    entity.url = file.url

    try? context.save()
  }
}
```

### Batch Upsert
```swift
cacheFiles: { files in
  let context = persistentContainer.viewContext

  await context.perform {
    for file in files {
      let request = NSFetchRequest<FileMO>(entityName: "File")
      request.predicate = NSPredicate(format: "fileId == %@", file.fileId)

      let existing = try? context.fetch(request).first
      let entity = existing ?? FileMO(context: context)

      // Update properties
      entity.fileId = file.fileId
      entity.key = file.key
      // ... other properties
    }

    try? context.save()
  }
}
```

### Fetch with Sorting
```swift
getFiles: {
  let context = persistentContainer.viewContext

  return await context.perform {
    let request = NSFetchRequest<FileMO>(entityName: "File")
    request.sortDescriptors = [
      NSSortDescriptor(key: "publishDate", ascending: false)
    ]

    let results = try? context.fetch(request)
    return results?.map { File(from: $0) } ?? []
  }
}
```

### Delete with Cascade
```swift
deleteFile: { file in
  let context = persistentContainer.viewContext

  await context.perform {
    let request = NSFetchRequest<FileMO>(entityName: "File")
    request.predicate = NSPredicate(format: "fileId == %@", file.fileId)

    if let entity = try? context.fetch(request).first {
      context.delete(entity)
      try? context.save()
    }
  }

  // Also delete local file
  if let url = file.url {
    try? FileManager.default.removeItem(at: fileClient.filePath(url))
  }
}
```

---

## Usage in Reducers

### Loading Cached Data
```swift
case .onAppear:
  return .run { send in
    let files = try await coreDataClient.getFiles()
    await send(.localFilesLoaded(files))
  }
```

### Caching Server Response
```swift
case let .remoteFilesResponse(.success(response)):
  // Update UI state
  state.files = IdentifiedArray(uniqueElements: response.body?.contents ?? [])

  // Persist to CoreData
  return .run { _ in
    try await coreDataClient.cacheFiles(response.body?.contents ?? [])
  }
```

### Deleting File
```swift
case .deleteButtonTapped:
  let file = state.file
  return .run { send in
    try await coreDataClient.deleteFile(file)
    await send(.delegate(.fileDeleted(file)))
  }
```

---

## Model Mapping

### CoreData → Domain Model
```swift
extension File {
  init(from entity: FileMO) {
    self.fileId = entity.fileId ?? UUID().uuidString
    self.key = entity.key ?? ""
    self.title = entity.title
    self.authorName = entity.authorName
    self.publishDate = entity.publishDate
    self.size = entity.size > 0 ? Int(entity.size) : nil
    self.url = entity.url
  }
}
```

### Domain Model → CoreData
```swift
extension FileMO {
  func update(from file: File) {
    self.fileId = file.fileId
    self.key = file.key
    self.title = file.title
    self.authorName = file.authorName
    self.publishDate = file.publishDate
    self.size = Int64(file.size ?? 0)
    self.url = file.url
  }
}
```

---

## Context Configuration

### Merge Policy
```swift
let context = persistentContainer.viewContext
context.mergePolicy = NSOverwriteMergePolicy
```

### Thread Safety
Always use `context.perform` for thread-safe access:

```swift
await context.perform {
  // CoreData operations here
}
```

---

## Truncation

### Clear All Files
```swift
truncateFiles: {
  let context = persistentContainer.viewContext

  await context.perform {
    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "File")
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
    try? context.execute(deleteRequest)
    try? context.save()
  }

  // Also delete all downloaded files
  let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  let extensions = ["mp4", "mp3", "m4a", "mov", "m4v", "wav", "webm"]

  if let files = try? FileManager.default.contentsOfDirectory(atPath: documentsURL.path) {
    for file in files {
      if extensions.contains(where: { file.hasSuffix($0) }) {
        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(file))
      }
    }
  }
}
```

---

## Anti-Patterns

### Don't access CoreData directly in reducers
```swift
// ❌ Wrong
case .loadFiles:
  let context = persistentContainer.viewContext
  // Direct CoreData access in reducer

// ✅ Correct
case .loadFiles:
  return .run { send in
    let files = try await coreDataClient.getFiles()
    await send(.filesLoaded(files))
  }
```

### Don't forget context.perform
```swift
// ❌ Wrong - Not thread-safe
let results = try context.fetch(request)

// ✅ Correct
await context.perform {
  let results = try context.fetch(request)
}
```

---

## Rationale

- **Offline support**: Data persists across app launches
- **Performance**: Local queries are fast
- **Testability**: CoreDataClient can be mocked in tests

---

## Related Patterns
- [Dependency-Client-Design.md](../TCA/Dependency-Client-Design.md)
- [Dependency-Mocking.md](../Testing/Dependency-Mocking.md)
