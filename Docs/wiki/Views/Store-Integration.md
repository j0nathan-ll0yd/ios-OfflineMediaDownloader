# Store Integration

## Quick Reference
- **When to use**: All views that use TCA stores
- **Enforcement**: Zero-tolerance
- **Impact if violated**: Critical - Observation breaks

---

## The Rule

Views using TCA stores MUST use `@Bindable var store: StoreOf<Feature>`. **NEVER** use `@State`, `@StateObject`, or `@ObservedObject` for TCA-managed state.

---

## Basic Pattern

```swift
import SwiftUI
import ComposableArchitecture

struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>

  var body: some View {
    VStack {
      Text(store.title)

      Button("Tap") {
        store.send(.buttonTapped)
      }
    }
  }
}
```

---

## @Bindable Explained

`@Bindable` enables:
1. **Direct property access**: `store.propertyName`
2. **Automatic bindings**: `$store.propertyName`
3. **Action sending**: `store.send(.action)`

```swift
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>

  var body: some View {
    VStack {
      // Direct access
      Text(store.title)

      // Binding for TextField
      TextField("Name", text: $store.name)

      // Sending actions
      Button("Submit") {
        store.send(.submitTapped)
      }
    }
  }
}
```

---

## Reading State

### Direct Property Access
```swift
// Simple properties
Text(store.title)
Text("\(store.count)")

// Optional handling
if let error = store.errorMessage {
  Text(error)
}

// Conditional rendering
if store.isLoading {
  ProgressView()
}
```

### Computed Properties
Access computed properties from state:

```swift
// In Feature State
@ObservableState
struct State: Equatable {
  var file: File
  var isPending: Bool { file.url == nil }
}

// In View
if store.isPending {
  Text("Processing...")
}
```

---

## Sending Actions

### Button Taps
```swift
Button("Refresh") {
  store.send(.refreshButtonTapped)
}
```

### With Parameters
```swift
Button("Delete") {
  store.send(.deleteItem(store.selectedId))
}
```

### Lifecycle
```swift
.onAppear {
  store.send(.onAppear)
}

.onDisappear {
  store.send(.onDisappear)
}

.task {
  await store.send(.task).finish()
}
```

---

## Creating Stores

### In App Entry Point
```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(initialState: RootFeature.State()) {
          RootFeature()
        }
      )
    }
  }
}
```

### In Previews
```swift
#Preview {
  MyView(
    store: Store(initialState: MyFeature.State(title: "Preview")) {
      MyFeature()
    }
  )
}
```

### With Dependencies Override
```swift
#Preview {
  MyView(
    store: Store(initialState: MyFeature.State()) {
      MyFeature()
    } withDependencies: {
      $0.serverClient = .testValue
    }
  )
}
```

---

## Anti-Patterns

### Never use @State with TCA
```swift
// ❌ FORBIDDEN
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
  @State private var localValue: String = ""  // NEVER
}

// ✅ CORRECT - All state in feature
@ObservableState
struct State: Equatable {
  var value: String = ""
}
```

### Never use @StateObject
```swift
// ❌ FORBIDDEN
struct MyView: View {
  @StateObject var viewModel = ViewModel()  // NEVER with TCA
}

// ✅ CORRECT
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
}
```

### Never create Store inside View
```swift
// ❌ FORBIDDEN
struct MyView: View {
  var body: some View {
    let store = Store(...)  // Creates new store on every render
  }
}

// ✅ CORRECT - Store passed in
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
}
```

---

## View Initialization

### Required Store Parameter
```swift
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>

  // No init needed - @Bindable handles it
}

// Usage
MyView(store: someStore)
```

### With Additional Parameters
```swift
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
  let additionalConfig: Config

  // Usage
  MyView(store: someStore, additionalConfig: config)
}
```

---

## Testing Views with Stores

```swift
import Testing
import ComposableArchitecture

@MainActor
@Test func viewRendersCorrectly() async {
  let store = Store(initialState: MyFeature.State(title: "Test")) {
    MyFeature()
  }

  // View can be created with store
  let _ = MyView(store: store)
}
```

---

## Rationale

- **Single source of truth**: All state managed by TCA
- **Automatic observation**: @Bindable handles observation setup
- **Predictable updates**: State changes flow through actions
- **Testability**: Store state is inspectable

---

## Related Patterns
- [Binding-Patterns.md](Binding-Patterns.md)
- [Child-Feature-Scoping.md](Child-Feature-Scoping.md)
- [Reducer-Patterns.md](../TCA/Reducer-Patterns.md)
