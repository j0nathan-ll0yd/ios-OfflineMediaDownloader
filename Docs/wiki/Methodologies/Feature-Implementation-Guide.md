# Feature Implementation Guide

## Quick Reference
- **When to use**: Adding any new feature to the app
- **Enforcement**: Required
- **Impact if violated**: High - Inconsistent architecture

---

## Overview

This guide walks through implementing a complete TCA feature from scratch, following project conventions.

---

## Step 1: Create the Reducer

### File Location
- If tightly coupled with view: `App/Views/FeatureView.swift`
- If standalone or used by multiple views: `App/Features/Feature.swift`

### Reducer Template
```swift
import ComposableArchitecture
import Foundation

@Reducer
struct MyFeature {
  @ObservableState
  struct State: Equatable {
    // Required state
    var items: IdentifiedArrayOf<ItemFeature.State> = []
    var isLoading: Bool = false
    var errorMessage: String?

    // Optional computed properties
    var isEmpty: Bool { items.isEmpty && !isLoading }
  }

  enum Action {
    // Lifecycle
    case onAppear

    // User interactions
    case refreshButtonTapped
    case itemTapped(Item.ID)

    // Async responses
    case itemsLoaded(Result<[Item], Error>)

    // Child features
    case items(IdentifiedActionOf<ItemFeature>)

    // Delegate
    case delegate(Delegate)

    enum Delegate: Equatable {
      case itemSelected(Item)
      case authenticationRequired
    }
  }

  // Dependencies
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  // Cancel IDs
  private enum CancelID { case fetch }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          let items = try await coreDataClient.getItems()
          await send(.itemsLoaded(.success(items)))
        }

      case .refreshButtonTapped:
        state.isLoading = true
        return .run { send in
          await send(.itemsLoaded(Result {
            try await serverClient.getItems()
          }))
        }
        .cancellable(id: CancelID.fetch)

      case let .itemsLoaded(.success(items)):
        state.isLoading = false
        state.items = IdentifiedArray(uniqueElements: items.map {
          ItemFeature.State(item: $0)
        })
        return .none

      case let .itemsLoaded(.failure(error)):
        state.isLoading = false
        if let serverError = error as? ServerClientError,
           serverError == .unauthorized {
          return .send(.delegate(.authenticationRequired))
        }
        state.errorMessage = error.localizedDescription
        return .none

      case let .itemTapped(id):
        if let item = state.items[id: id]?.item {
          return .send(.delegate(.itemSelected(item)))
        }
        return .none

      case .items:
        return .none

      case .delegate:
        return .none
      }
    }
    .forEach(\.items, action: \.items) {
      ItemFeature()
    }
  }
}
```

---

## Step 2: Create the View

### View Template
```swift
import SwiftUI
import ComposableArchitecture

struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("My Feature")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              store.send(.refreshButtonTapped)
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            .disabled(store.isLoading)
          }
        }
    }
    .onAppear {
      store.send(.onAppear)
    }
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
  }

  @ViewBuilder
  private var content: some View {
    if store.isLoading && store.items.isEmpty {
      ProgressView("Loading...")
    } else if store.isEmpty {
      emptyState
    } else {
      list
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "tray")
        .font(.system(size: 60))
        .foregroundColor(.secondary)
      Text("No items yet")
        .font(.headline)
    }
  }

  private var list: some View {
    List {
      ForEach(store.scope(state: \.items, action: \.items)) { itemStore in
        ItemView(store: itemStore)
      }
    }
    .refreshable {
      store.send(.refreshButtonTapped)
    }
  }
}

#Preview {
  MyView(
    store: Store(initialState: MyFeature.State()) {
      MyFeature()
    }
  )
}
```

---

## Step 3: Integrate with Parent

### Add to Parent State
```swift
// In ParentFeature
@ObservableState
struct State: Equatable {
  var myFeature: MyFeature.State = MyFeature.State()
}
```

### Add to Parent Action
```swift
enum Action {
  case myFeature(MyFeature.Action)
}
```

### Add Scope to Parent Reducer
```swift
var body: some ReducerOf<Self> {
  Scope(state: \.myFeature, action: \.myFeature) {
    MyFeature()
  }

  Reduce { state, action in
    switch action {
    // Handle delegate actions
    case .myFeature(.delegate(.authenticationRequired)):
      return .send(.logout)

    case .myFeature:
      return .none
    }
  }
}
```

### Add to Parent View
```swift
MyView(store: store.scope(state: \.myFeature, action: \.myFeature))
```

---

## Step 4: Add Dependencies (if needed)

### Create Dependency Client
See [Dependency-Client-Design.md](../TCA/Dependency-Client-Design.md)

```swift
// App/Dependencies/MyClient.swift

@DependencyClient
struct MyClient {
  var fetch: @Sendable () async throws -> [Item]
  var save: @Sendable (_ item: Item) async throws -> Void
}

extension DependencyValues {
  var myClient: MyClient {
    get { self[MyClient.self] }
    set { self[MyClient.self] = newValue }
  }
}

extension MyClient: DependencyKey {
  static let liveValue = MyClient(
    fetch: { /* implementation */ },
    save: { _ in /* implementation */ }
  )
}

extension MyClient {
  static let testValue = MyClient(
    fetch: { [] },
    save: { _ in }
  )
}
```

---

## Step 5: Write Tests

```swift
import Testing
import ComposableArchitecture

@testable import OfflineMediaDownloader

@MainActor
struct MyFeatureTests {
  @Test func loadsItemsOnAppear() async throws {
    let testItems = [Item(id: "1", name: "Test")]

    let store = TestStoreOf<MyFeature>(
      initialState: MyFeature.State()
    ) {
      MyFeature()
    } withDependencies: {
      $0.coreDataClient.getItems = { testItems }
    }

    await store.send(.onAppear)

    await store.receive(\.itemsLoaded.success) {
      $0.items = IdentifiedArray(uniqueElements: testItems.map {
        ItemFeature.State(item: $0)
      })
    }
  }

  @Test func handlesAuthError() async throws {
    let store = TestStoreOf<MyFeature>(
      initialState: MyFeature.State()
    ) {
      MyFeature()
    } withDependencies: {
      $0.serverClient.getItems = {
        throw ServerClientError.unauthorized
      }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.itemsLoaded.failure) {
      $0.isLoading = false
    }

    await store.receive(\.delegate.authenticationRequired)
  }
}
```

---

## Checklist

### Reducer
- [ ] `@Reducer` struct
- [ ] `@ObservableState` State with `Equatable`
- [ ] Action enum with all cases
- [ ] Delegate enum for parent communication
- [ ] `@Dependency` for external services
- [ ] `CancelID` enum for async operations
- [ ] `body` property returns `some ReducerOf<Self>`
- [ ] All actions handled in switch
- [ ] Delegate actions return `.none`

### View
- [ ] `@Bindable var store: StoreOf<Feature>`
- [ ] No `@State` or `@StateObject`
- [ ] `.onAppear { store.send(.onAppear) }`
- [ ] Error alert binding
- [ ] Loading state handling
- [ ] Empty state handling
- [ ] Preview with test store

### Integration
- [ ] Parent state includes child state
- [ ] Parent action includes child action
- [ ] `Scope()` in parent reducer body
- [ ] Delegate actions handled in parent
- [ ] View scoped in parent view

### Testing
- [ ] Success path tested
- [ ] Error path tested
- [ ] Delegate emissions tested
- [ ] Dependencies mocked

---

## Related Patterns
- [Reducer-Patterns.md](../TCA/Reducer-Patterns.md)
- [Store-Integration.md](../Views/Store-Integration.md)
- [Delegation-Pattern.md](../TCA/Delegation-Pattern.md)
- [TestStore-Usage.md](../Testing/TestStore-Usage.md)
