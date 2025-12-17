# Feature State Design

## Quick Reference
- **When to use**: Designing state for any feature
- **Enforcement**: Required
- **Impact if violated**: High - UI inconsistencies, bugs

---

## The Rule

State should be the single source of truth for UI. All data displayed by a view must live in the feature's state.

---

## State Design Principles

### 1. Include All UI-Displayed Data
```swift
@ObservableState
struct State: Equatable {
  // Data to display
  var files: IdentifiedArrayOf<FileCellFeature.State> = []

  // UI state
  var isLoading: Bool = false
  var errorMessage: String?

  // Interaction state
  var showAddConfirmation: Bool = false
  var playingFile: File?
}
```

### 2. Use Computed Properties for Derived Data
```swift
@ObservableState
struct State: Equatable {
  var file: File

  // ✅ Derived from file.url
  var isPending: Bool { file.url == nil }

  // ✅ Derived from file.size
  var formattedSize: String {
    guard let size = file.size else { return "" }
    return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
  }
}
```

### 3. Cache Expensive Computations
```swift
@ObservableState
struct State: Equatable {
  var file: File

  // ✅ Cached to avoid filesystem check in View.body
  var isDownloaded: Bool = false  // Set in .onAppear
}
```

### 4. Use IdentifiedArray for Collections
```swift
@ObservableState
struct State: Equatable {
  // ✅ IdentifiedArray for efficient updates
  var files: IdentifiedArrayOf<FileCellFeature.State> = []
}
```

---

## State Patterns by Use Case

### Loading States
```swift
@ObservableState
struct State: Equatable {
  var items: [Item] = []
  var isLoading: Bool = false
  var errorMessage: String?

  // Computed convenience
  var isEmpty: Bool { items.isEmpty && !isLoading }
  var showEmptyState: Bool { isEmpty && errorMessage == nil }
}
```

### Form States
```swift
@ObservableState
struct State: Equatable {
  var email: String = ""
  var password: String = ""
  var isSubmitting: Bool = false
  var validationError: String?

  // Derived validation
  var isValid: Bool {
    !email.isEmpty && password.count >= 8
  }
}
```

### Selection States
```swift
@ObservableState
struct State: Equatable {
  var items: IdentifiedArrayOf<Item> = []
  var selectedId: Item.ID?

  // Derived selection
  var selectedItem: Item? {
    selectedId.flatMap { items[id: $0]?.item }
  }
}
```

### Tab States
```swift
@ObservableState
struct State: Equatable {
  var selectedTab: Tab = .files

  // Child feature states
  var fileList: FileListFeature.State = FileListFeature.State()
  var diagnostic: DiagnosticFeature.State = DiagnosticFeature.State()

  enum Tab: Equatable, Sendable {
    case files
    case account
  }
}
```

### Download Progress States
```swift
@ObservableState
struct State: Equatable, Identifiable {
  var file: File
  var id: String { file.fileId }

  // Download state
  var isDownloading: Bool = false
  var downloadProgress: Double = 0
  var isDownloaded: Bool = false

  // Derived
  var isPending: Bool { file.url == nil }
  var canDownload: Bool { !isPending && !isDownloaded && !isDownloading }
}
```

---

## State Preservation Pattern

When refreshing data, preserve UI state:

```swift
case let .refreshResponse(.success(newFiles)):
  // Save existing states by ID
  let existingStates = Dictionary(
    uniqueKeysWithValues: state.files.map { ($0.id, $0) }
  )

  // Map new data, preserving UI state
  state.files = IdentifiedArray(uniqueElements: newFiles.map { file in
    var newState = FileCellFeature.State(file: file)
    if let existing = existingStates[file.fileId] {
      // Preserve download state
      newState.isDownloaded = existing.isDownloaded
      newState.isDownloading = existing.isDownloading
      newState.downloadProgress = existing.downloadProgress
    }
    return newState
  })
  return .none
```

---

## Identifiable Conformance

For child features in collections:

```swift
@ObservableState
struct State: Equatable, Identifiable {
  var file: File

  // Use model's ID
  var id: String { file.fileId }
}
```

---

## Anti-Patterns

### Don't Store Formatters in State
```swift
// ❌ Wrong
@ObservableState
struct State: Equatable {
  var dateFormatter: DateFormatter  // Not Equatable-friendly
}

// ✅ Correct - Use computed or external helper
var formattedDate: String {
  DateFormatter.relative.string(from: date)
}
```

### Don't Duplicate Data
```swift
// ❌ Wrong - title duplicated
@ObservableState
struct State: Equatable {
  var file: File
  var title: String  // Already in file.title
}

// ✅ Correct - Single source
@ObservableState
struct State: Equatable {
  var file: File
  // Use file.title directly
}
```

### Don't Store UI Component State
```swift
// ❌ Wrong
@ObservableState
struct State: Equatable {
  var scrollPosition: CGFloat  // Let SwiftUI manage
}

// ✅ Correct - Only store semantic state
@ObservableState
struct State: Equatable {
  var highlightedItemId: String?  // Semantic, not positional
}
```

---

## Rationale

- **Single source of truth**: Prevents UI/state inconsistencies
- **Testability**: State is fully inspectable in tests
- **Time travel debugging**: Complete app state at any point
- **Persistence**: Easy to serialize/restore state

---

## Related Patterns
- [Reducer-Patterns.md](Reducer-Patterns.md)
- [Store-Integration.md](../Views/Store-Integration.md)
