# Child Feature Scoping

## Quick Reference
- **When to use**: Passing stores to child views
- **Enforcement**: Required
- **Impact if violated**: High - Feature isolation breaks

---

## The Rule

Use `store.scope(state:action:)` to create child stores from parent stores. This maintains proper action routing and state isolation.

---

## Basic Scoping

### Single Child Feature
```swift
// Parent View
struct ParentView: View {
  @Bindable var store: StoreOf<ParentFeature>

  var body: some View {
    ChildView(
      store: store.scope(state: \.child, action: \.child)
    )
  }
}
```

### Corresponding Reducer Setup
```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable {
    var child: ChildFeature.State = ChildFeature.State()
  }

  enum Action {
    case child(ChildFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }

    Reduce { state, action in
      // Parent logic
    }
  }
}
```

---

## Collection Scoping

### ForEach with IdentifiedArray
```swift
// Parent View
struct FileListView: View {
  @Bindable var store: StoreOf<FileListFeature>

  var body: some View {
    List {
      ForEach(store.scope(state: \.files, action: \.files)) { cellStore in
        FileCellView(store: cellStore)
      }
    }
  }
}
```

### Corresponding Reducer Setup
```swift
@Reducer
struct FileListFeature {
  @ObservableState
  struct State: Equatable {
    var files: IdentifiedArrayOf<FileCellFeature.State> = []
  }

  enum Action {
    case files(IdentifiedActionOf<FileCellFeature>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Parent logic handling child delegates
    }
    .forEach(\.files, action: \.files) {
      FileCellFeature()
    }
  }
}
```

---

## Tab-Based Scoping

### TabView with Scoped Stores
```swift
struct MainView: View {
  @Bindable var store: StoreOf<MainFeature>

  var body: some View {
    TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
      FileListView(
        store: store.scope(state: \.fileList, action: \.fileList)
      )
      .tabItem { Label("Files", systemImage: "film.stack") }
      .tag(MainFeature.State.Tab.files)

      DiagnosticView(
        store: store.scope(state: \.diagnostic, action: \.diagnostic)
      )
      .tabItem { Label("Account", systemImage: "person.circle") }
      .tag(MainFeature.State.Tab.account)
    }
  }
}
```

### Corresponding Reducer
```swift
@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab = .files
    var fileList: FileListFeature.State = FileListFeature.State()
    var diagnostic: DiagnosticFeature.State = DiagnosticFeature.State()

    enum Tab: Equatable, Sendable {
      case files
      case account
    }
  }

  enum Action {
    case tabSelected(State.Tab)
    case fileList(FileListFeature.Action)
    case diagnostic(DiagnosticFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.fileList, action: \.fileList) {
      FileListFeature()
    }

    Scope(state: \.diagnostic, action: \.diagnostic) {
      DiagnosticFeature()
    }

    Reduce { state, action in
      switch action {
      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none
      case .fileList, .diagnostic:
        return .none
      }
    }
  }
}
```

---

## Optional Child Features

### Conditional Scoping
```swift
struct ParentView: View {
  @Bindable var store: StoreOf<ParentFeature>

  var body: some View {
    VStack {
      if store.main != nil {
        if let mainStore = store.scope(state: \.main, action: \.main) {
          MainView(store: mainStore)
        }
      } else {
        LoginView(store: store.scope(state: \.login, action: \.login))
      }
    }
  }
}
```

### With ifLet in Reducer
```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable {
    var login: LoginFeature.State = LoginFeature.State()
    var main: MainFeature.State?
  }

  enum Action {
    case login(LoginFeature.Action)
    case main(MainFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Reduce { state, action in
      // Handle transitions
    }
    .ifLet(\.main, action: \.main) {
      MainFeature()
    }
  }
}
```

---

## Navigation with Scoped Stores

### NavigationLink
```swift
NavigationLink {
  DetailView(
    store: store.scope(state: \.detail, action: \.detail)
  )
} label: {
  Text("View Details")
}
```

### Sheet
```swift
.sheet(
  isPresented: Binding(
    get: { store.showDetail },
    set: { if !$0 { store.send(.dismissDetail) } }
  )
) {
  DetailView(
    store: store.scope(state: \.detail, action: \.detail)
  )
}
```

---

## Real-World Example

### From RootView
```swift
struct RootView: View {
  @Bindable var store: StoreOf<RootFeature>

  var body: some View {
    Group {
      if store.isLaunching {
        LaunchView(status: store.launchStatus)
      } else if store.isAuthenticated, store.main != nil {
        if let mainStore = store.scope(state: \.main, action: \.main) {
          MainView(store: mainStore)
        }
      } else {
        LoginView(store: store.scope(state: \.login, action: \.login))
      }
    }
  }
}
```

---

## Handling Child Delegate Actions

### In Parent Reducer
```swift
var body: some ReducerOf<Self> {
  Scope(state: \.fileList, action: \.fileList) {
    FileListFeature()
  }

  Reduce { state, action in
    switch action {
    // Handle specific delegate action
    case .fileList(.delegate(.authenticationRequired)):
      return .send(.delegate(.authenticationRequired))

    // Ignore other child actions
    case .fileList:
      return .none
    }
  }
}
```

### Collection Delegate Actions
```swift
switch action {
// Element delegate action
case let .files(.element(id: _, action: .delegate(.fileDeleted(file)))):
  state.files.remove(id: file.fileId)
  return .none

case let .files(.element(id: _, action: .delegate(.playFile(file)))):
  state.playingFile = file
  return .none

// Other element actions
case .files:
  return .none
}
```

---

## Anti-Patterns

### Don't access child state directly in parent view
```swift
// ❌ Wrong - Breaks encapsulation
Text(store.child.someProperty)

// ✅ Correct - Scope and let child view handle it
ChildView(store: store.scope(state: \.child, action: \.child))
```

### Don't create scope in property
```swift
// ❌ Wrong - Creates new scope on every access
var childStore: StoreOf<ChildFeature> {
  store.scope(state: \.child, action: \.child)
}

// ✅ Correct - Create scope inline
ChildView(store: store.scope(state: \.child, action: \.child))
```

### Don't forget Scope in reducer
```swift
// ❌ Wrong - Child reducer not integrated
var body: some ReducerOf<Self> {
  Reduce { state, action in
    // Missing Scope combinator
  }
}

// ✅ Correct
var body: some ReducerOf<Self> {
  Scope(state: \.child, action: \.child) {
    ChildFeature()
  }

  Reduce { state, action in
    // ...
  }
}
```

---

## Rationale

- **Encapsulation**: Child features are isolated
- **Action routing**: Actions flow correctly through hierarchy
- **Reusability**: Child features can be used in different parents
- **Testability**: Child features can be tested independently

---

## Related Patterns
- [Store-Integration.md](Store-Integration.md)
- [Delegation-Pattern.md](../TCA/Delegation-Pattern.md)
- [Reducer-Patterns.md](../TCA/Reducer-Patterns.md)
