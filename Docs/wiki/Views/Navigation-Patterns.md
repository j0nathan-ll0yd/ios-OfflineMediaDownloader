# Navigation Patterns

## Quick Reference
- **When to use**: Any navigation in TCA views
- **Enforcement**: Required
- **Impact if violated**: Medium - Navigation state issues

---

## The Rule

Navigation state should be driven by feature state. Use bindings to connect SwiftUI navigation to TCA state.

---

## Tab Navigation

### TabView with Selection Binding
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

### State and Action
```swift
@ObservableState
struct State: Equatable {
  var selectedTab: Tab = .files

  enum Tab: Equatable, Sendable {
    case files
    case account
  }
}

enum Action {
  case tabSelected(State.Tab)
}

// In reducer
case let .tabSelected(tab):
  state.selectedTab = tab
  return .none
```

---

## NavigationStack

### Basic NavigationStack
```swift
struct FileListView: View {
  @Bindable var store: StoreOf<FileListFeature>

  var body: some View {
    NavigationStack {
      List {
        ForEach(store.scope(state: \.files, action: \.files)) { cellStore in
          FileCellView(store: cellStore)
        }
      }
      .navigationTitle("Files")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { store.send(.addButtonTapped) } label: {
            Image(systemName: "plus")
          }
        }
      }
    }
  }
}
```

### NavigationLink
```swift
NavigationLink(destination: PendingFilesView(fileIds: store.pendingFileIds)) {
  Image(systemName: "clock.arrow.circlepath")
    .foregroundColor(.orange)
}
```

---

## Sheet Presentation

### Boolean-Driven Sheet
```swift
.sheet(
  isPresented: Binding(
    get: { store.showDetail },
    set: { if !$0 { store.send(.dismissDetail) } }
  )
) {
  DetailView(store: store.scope(state: \.detail, action: \.detail))
}
```

### Item-Driven Sheet
```swift
.sheet(
  item: Binding(
    get: { store.selectedFile },
    set: { _ in store.send(.dismissFileDetail) }
  )
) { file in
  FileDetailView(file: file)
}
```

---

## Full Screen Cover

### With Dismiss Handler
```swift
.fullScreenCover(
  item: Binding(
    get: { store.playingFile },
    set: { _ in store.send(.dismissPlayer) }
  )
) { file in
  VideoPlayerView(url: fileClient.filePath(file.url!)) {
    store.send(.dismissPlayer)
  }
}
```

### Draggable Full Screen Cover
```swift
struct VideoPlayerView: View {
  let url: URL
  let onDismiss: () -> Void
  @State private var dragOffset: CGFloat = 0

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black.edgesIgnoringSafeArea(.all)

        VideoPlayer(player: player)
          .offset(y: dragOffset)
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            if value.translation.height > 0 {
              dragOffset = value.translation.height
            }
          }
          .onEnded { value in
            if value.translation.height > 150 {
              onDismiss()
            } else {
              withAnimation { dragOffset = 0 }
            }
          }
      )
    }
  }
}
```

---

## Alert and Confirmation Dialog

### Error Alert
```swift
.alert(
  "Error",
  isPresented: Binding(
    get: { store.errorMessage != nil },
    set: { if !$0 { store.send(.clearError) } }
  )
) {
  Button("OK") { store.send(.clearError) }
} message: {
  Text(store.errorMessage ?? "")
}
```

### Confirmation Dialog
```swift
.confirmationDialog(
  "Add Video",
  isPresented: Binding(
    get: { store.showAddConfirmation },
    set: { _ in store.send(.confirmationDismissed) }
  ),
  titleVisibility: .visible
) {
  Button("From Clipboard") {
    store.send(.addFromClipboard)
  }
  Button("Cancel", role: .cancel) {
    store.send(.confirmationDismissed)
  }
}
```

### Destructive Confirmation
```swift
.confirmationDialog(
  "Delete File",
  isPresented: Binding(
    get: { store.showDeleteConfirmation },
    set: { _ in store.send(.cancelDelete) }
  )
) {
  Button("Delete", role: .destructive) {
    store.send(.confirmDelete)
  }
  Button("Cancel", role: .cancel) {
    store.send(.cancelDelete)
  }
} message: {
  Text("This action cannot be undone.")
}
```

---

## Conditional Root View

### Authentication-Based Navigation
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

## Pull-to-Refresh

```swift
List {
  // Content
}
.refreshable {
  store.send(.refreshButtonTapped)
}
```

---

## Swipe Actions

```swift
List {
  ForEach(store.scope(state: \.files, action: \.files)) { cellStore in
    FileCellView(store: cellStore)
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
          store.send(.deleteFile(cellStore.id))
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
  }
}
```

---

## Navigation State Pattern

### State Structure
```swift
@ObservableState
struct State: Equatable {
  // Navigation flags
  var showDetail: Bool = false
  var showAddSheet: Bool = false

  // Selected items
  var selectedFile: File?
  var playingFile: File?

  // Error state (for alerts)
  var errorMessage: String?
}
```

### Actions
```swift
enum Action {
  // Presentation
  case showDetailTapped
  case dismissDetail

  // Selection
  case fileSelected(File)
  case clearSelection

  // Playback
  case playFile(File)
  case dismissPlayer

  // Errors
  case setError(String)
  case clearError
}
```

---

## Anti-Patterns

### Don't use @State for navigation
```swift
// ❌ Wrong
@State private var showSheet = false

.sheet(isPresented: $showSheet) { }

// ✅ Correct - Use store state
.sheet(
  isPresented: Binding(
    get: { store.showSheet },
    set: { if !$0 { store.send(.dismissSheet) } }
  )
) { }
```

### Don't ignore dismiss events
```swift
// ❌ Wrong - Navigation can't be dismissed
.sheet(isPresented: .constant(true)) { }

// ✅ Correct
.sheet(
  isPresented: Binding(
    get: { store.showSheet },
    set: { if !$0 { store.send(.dismissSheet) } }
  )
) { }
```

---

## Rationale

- **State-driven**: Navigation reflects feature state
- **Testability**: Navigation can be tested via actions
- **Consistency**: Same patterns across all navigation types
- **Deep linking**: State can be restored from URLs

---

## Related Patterns
- [Binding-Patterns.md](Binding-Patterns.md)
- [Store-Integration.md](Store-Integration.md)
- [Feature-State-Design.md](../TCA/Feature-State-Design.md)
