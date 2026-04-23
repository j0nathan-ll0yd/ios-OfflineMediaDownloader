import ComposableArchitecture
import Foundation
@testable import OfflineMediaDownloader
import Testing

@Suite(.serialized)
struct MainFeatureTests {
  // MARK: - Tab Selection Tests

  @MainActor
  @Test("Tab selection updates selected tab to account")
  func tabSelectionAccount() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.tabSelected(.account)) {
      $0.selectedTab = .account
    }
  }

  @MainActor
  @Test("Tab selection updates selected tab to files")
  func tabSelectionFiles() async {
    var state = MainFeature.State()
    state.selectedTab = .account

    let store = TestStore(initialState: state) {
      MainFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.tabSelected(.files)) {
      $0.selectedTab = .files
    }
  }

  // MARK: - Delegate Propagation Tests

  @MainActor
  @Test("Auth required from file list propagates to delegate")
  func authRequiredFromFileList() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.fileList(.delegate(.authenticationRequired)))
    await store.receive(\.delegate.authenticationRequired)
  }

  // MARK: - Child Feature Action Pass-through Tests

  @MainActor
  @Test("FileList actions pass through without state change")
  func fileListActionsPassThrough() async {
    let state = MainFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.fileList.$isAuthenticated.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      MainFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    // Non-delegate actions should pass through (when authenticated)
    await store.send(.fileList(.addButtonTapped)) {
      $0.fileList.showAddConfirmation = true
    }
  }

  @MainActor
  @Test("Diagnostic actions pass through without state change")
  func diagnosticActionsPassThrough() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.diagnostic(.toggleDebugMode)) {
      $0.diagnostic.showDebugActions = true
    }
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has files tab selected")
  func initialStateFilesTab() {
    let state = MainFeature.State()
    #expect(state.selectedTab == .files)
  }

  @MainActor
  @Test("Initial state has empty file list")
  func initialStateEmptyFileList() {
    let state = MainFeature.State()
    #expect(state.fileList.files.isEmpty)
  }

  @MainActor
  @Test("Initial state has empty keychain items in diagnostic")
  func initialStateEmptyDiagnostic() {
    let state = MainFeature.State()
    #expect(state.diagnostic.keychainItems.isEmpty)
  }

  // MARK: - Tab Enum Tests

  @MainActor
  @Test("Tab enum is Equatable and Sendable")
  func tabEnumConformance() {
    let tab1: MainFeature.State.Tab = .files
    let tab2: MainFeature.State.Tab = .files
    let tab3: MainFeature.State.Tab = .account

    #expect(tab1 == tab2)
    #expect(tab1 != tab3)
  }
}
