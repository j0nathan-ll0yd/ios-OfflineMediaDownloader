# Binding Patterns

## Quick Reference
- **When to use**: Two-way data binding in TCA views
- **Enforcement**: Required
- **Impact if violated**: High - State sync issues

---

## The Rule

Use `$store.property` for simple bindings or `$store.property.sending(\.action)` for bindings that need to trigger specific actions.

---

## Basic Binding Patterns

### Direct Binding (Automatic Action)
For `@ObservableState` properties, bindings are automatic:

```swift
// Feature
@ObservableState
struct State: Equatable {
  var text: String = ""
}

// View
TextField("Enter text", text: $store.text)
```

### Binding with Action
When you need to trigger a specific action:

```swift
// Feature
enum Action {
  case textChanged(String)
}

// View
TextField("Enter text", text: $store.text.sending(\.textChanged))
```

---

## Common Binding Scenarios

### TextField
```swift
TextField("Email", text: $store.email.sending(\.emailChanged))
```

### Toggle
```swift
Toggle("Enable notifications", isOn: $store.notificationsEnabled.sending(\.toggleNotifications))
```

### Picker/TabView
```swift
TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
  FileListView(store: store.scope(state: \.fileList, action: \.fileList))
    .tag(State.Tab.files)

  DiagnosticView(store: store.scope(state: \.diagnostic, action: \.diagnostic))
    .tag(State.Tab.account)
}
```

### Slider
```swift
Slider(value: $store.volume.sending(\.volumeChanged), in: 0...1)
```

---

## Alert and Sheet Bindings

### Alert with Boolean
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

### Sheet
```swift
.sheet(
  isPresented: Binding(
    get: { store.showingDetail },
    set: { if !$0 { store.send(.dismissDetail) } }
  )
) {
  DetailView()
}
```

### Full Screen Cover with Item
```swift
.fullScreenCover(
  item: Binding(
    get: { store.playingFile },
    set: { _ in store.send(.dismissPlayer) }
  )
) { file in
  VideoPlayerView(file: file) {
    store.send(.dismissPlayer)
  }
}
```

---

## Custom Binding Patterns

### Derived Binding
When the binding value needs transformation:

```swift
Binding(
  get: { store.count.description },
  set: { store.send(.countChanged(Int($0) ?? 0)) }
)
```

### Optional to Non-Optional
```swift
// Store has optional, TextField needs non-optional
TextField(
  "Name",
  text: Binding(
    get: { store.name ?? "" },
    set: { store.send(.nameChanged($0.isEmpty ? nil : $0)) }
  )
)
```

### Index-Based Selection
```swift
Picker("Item", selection: Binding(
  get: { store.items.firstIndex(where: { $0.id == store.selectedId }) ?? 0 },
  set: { store.send(.itemSelected(store.items[$0].id)) }
)) {
  ForEach(store.items.indices, id: \.self) { index in
    Text(store.items[index].name).tag(index)
  }
}
```

---

## Real-World Examples

### From FileListView
```swift
// Confirmation dialog
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

// Error alert
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

// Full screen cover
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

---

## Binding vs Sending

| Use Binding | Use Send |
|-------------|----------|
| Continuous updates (typing) | One-time events (button tap) |
| SwiftUI controls need it | Custom interactions |
| Two-way sync needed | Fire-and-forget |

```swift
// Binding - continuous sync
TextField("Email", text: $store.email.sending(\.emailChanged))

// Send - one-time action
Button("Submit") {
  store.send(.submitTapped)
}
```

---

## Anti-Patterns

### Don't create local @State for TCA values
```swift
// ❌ Wrong
@State private var localText: String = ""

TextField("Text", text: $localText)
  .onChange(of: localText) { store.send(.textChanged($0)) }

// ✅ Correct
TextField("Text", text: $store.text.sending(\.textChanged))
```

### Don't ignore dismiss events
```swift
// ❌ Wrong - No way to dismiss
.sheet(isPresented: .constant(store.showSheet)) { }

// ✅ Correct - Handle dismiss
.sheet(
  isPresented: Binding(
    get: { store.showSheet },
    set: { if !$0 { store.send(.dismissSheet) } }
  )
) { }
```

---

## Rationale

- **State consistency**: Bindings keep UI and state in sync
- **Action tracking**: All changes flow through actions
- **Testability**: Binding changes are testable via actions

---

## Related Patterns
- [Store-Integration.md](Store-Integration.md)
- [Feature-State-Design.md](../TCA/Feature-State-Design.md)
