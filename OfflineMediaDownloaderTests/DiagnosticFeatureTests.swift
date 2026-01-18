import ConcurrencyExtras
import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("DiagnosticFeature Tests")
struct DiagnosticFeatureTests {

  // MARK: - Keychain Loading Tests

  @MainActor
  @Test("onAppear loads all keychain items")
  func onAppearLoadsAllItems() async throws {
    let testToken = "test-token-012345678901234567890123456789012345678"  // 50 chars
    let testExpiration = Date().addingTimeInterval(3600)
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.getJwtToken = { testToken }
      $0.keychainClient.getUserData = { TestData.sampleUser }
      $0.keychainClient.getDeviceData = { TestData.sampleDevice }
      $0.keychainClient.getTokenExpiresAt = { testExpiration }
      $0.coreDataClient.getMetrics = { FileMetrics(downloadCount: 0, totalStorageBytes: 0, playCount: 0) }
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    // .loadMetrics is sent synchronously, while keychainItemsLoaded comes from async run
    await store.receive(\.loadMetrics)
    // Metrics are already 0 in initial state, so no state change to assert
    await store.receive(\.metricsLoaded)

    await store.receive(\.tokenExpirationLoaded) {
      $0.tokenExpiresAt = testExpiration
    }

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = [
        KeychainItem(name: "Token", displayValue: testToken, itemType: .token),
        KeychainItem(
          name: "UserData",
          displayValue: "\(TestData.sampleUser.firstName) \(TestData.sampleUser.lastName) (\(TestData.sampleUser.email))",
          itemType: .userData
        ),
        KeychainItem(name: "DeviceData", displayValue: TestData.sampleDevice.endpointArn, itemType: .deviceData)
      ]
    }
  }

  @MainActor
  @Test("onAppear with only token shows token item")
  func onAppearOnlyToken() async throws {
    let testToken = "short-token"
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.getJwtToken = { testToken }
      $0.keychainClient.getUserData = { throw KeychainError.unableToStore }
      $0.keychainClient.getDeviceData = { nil }
      $0.keychainClient.getTokenExpiresAt = { nil }
      $0.coreDataClient.getMetrics = { FileMetrics(downloadCount: 0, totalStorageBytes: 0, playCount: 0) }
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    // .loadMetrics is sent synchronously, while keychainItemsLoaded comes from async run
    await store.receive(\.loadMetrics)
    await store.receive(\.metricsLoaded)

    await store.receive(\.tokenExpirationLoaded)
    // tokenExpiresAt remains nil

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = [
        KeychainItem(name: "Token", displayValue: testToken, itemType: .token)
      ]
    }
  }

  @MainActor
  @Test("onAppear with no keychain items shows empty list")
  func onAppearNoItems() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.getJwtToken = { nil }
      $0.keychainClient.getUserData = { throw KeychainError.unableToStore }
      $0.keychainClient.getDeviceData = { nil }
      $0.keychainClient.getTokenExpiresAt = { nil }
      $0.coreDataClient.getMetrics = { FileMetrics(downloadCount: 0, totalStorageBytes: 0, playCount: 0) }
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    // .loadMetrics is sent synchronously, while keychainItemsLoaded comes from async run
    await store.receive(\.loadMetrics)
    await store.receive(\.metricsLoaded)

    await store.receive(\.tokenExpirationLoaded)
    // tokenExpiresAt remains nil

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = []
    }
  }

  // MARK: - Debug Mode Tests

  @MainActor
  @Test("Toggle debug mode shows debug actions")
  func toggleDebugModeOn() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    }

    await store.send(.toggleDebugMode) {
      $0.showDebugActions = true
    }
  }

  @MainActor
  @Test("Toggle debug mode hides debug actions")
  func toggleDebugModeOff() async throws {
    var state = DiagnosticFeature.State()
    state.showDebugActions = true

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    }

    await store.send(.toggleDebugMode) {
      $0.showDebugActions = false
    }
  }

  // MARK: - Delete Keychain Item Tests

  @MainActor
  @Test("Delete token removes from keychain and list")
  func deleteToken() async throws {
    let deleteTokenCalled = LockIsolated(false)
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "Token", displayValue: "test...", itemType: .token),
      KeychainItem(name: "UserData", displayValue: "Test User", itemType: .userData)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteJwtToken = { deleteTokenCalled.setValue(true) }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.keychainItemDeleted)
    await store.receive(\.delegate.authenticationInvalidated)
    #expect(deleteTokenCalled.value == true)
  }

  @MainActor
  @Test("Delete user data removes from keychain and list")
  func deleteUserData() async throws {
    let deleteUserDataCalled = LockIsolated(false)
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "UserData", displayValue: "Test User", itemType: .userData)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteUserData = { deleteUserDataCalled.setValue(true) }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.keychainItemDeleted)
    await store.receive(\.delegate.authenticationInvalidated)
    #expect(deleteUserDataCalled.value == true)
  }

  @MainActor
  @Test("Delete device data removes from keychain and list")
  func deleteDeviceData() async throws {
    let deleteDeviceDataCalled = LockIsolated(false)
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "DeviceData", displayValue: "arn:aws:sns:test", itemType: .deviceData)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteDeviceData = { deleteDeviceDataCalled.setValue(true) }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.keychainItemDeleted)
    #expect(deleteDeviceDataCalled.value == true)
  }

  @MainActor
  @Test("Delete with empty index set does nothing")
  func deleteEmptyIndexSet() async throws {
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "Token", displayValue: "test...", itemType: .token)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    }

    await store.send(.deleteKeychainItem(IndexSet()))
    // No state change or effect expected
  }

  // MARK: - Truncate Files Tests

  @MainActor
  @Test("Truncate files calls coreDataClient")
  func truncateFiles() async throws {
    let truncateCalled = LockIsolated(false)

    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.coreDataClient.truncateFiles = { truncateCalled.setValue(true) }
      $0.coreDataClient.resetMetrics = { }
      $0.coreDataClient.getMetrics = { FileMetrics(downloadCount: 0, totalStorageBytes: 0, playCount: 0) }
    }

    await store.send(.truncateFilesButtonTapped)
    await store.receive(\.filesTruncated)
    await store.receive(\.loadMetrics)
    await store.receive(\.metricsLoaded)

    #expect(truncateCalled.value == true)
  }

  // MARK: - Error Handling Tests

  @MainActor
  @Test("Delete keychain error shows alert")
  func deleteKeychainError() async throws {
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "Token", displayValue: "test...", itemType: .token)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteJwtToken = { throw KeychainError.unableToStore }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Security Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Failed to delete Token secure data.")
      }
    }
  }

  @MainActor
  @Test("Truncate files error shows alert")
  func truncateFilesError() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.coreDataClient.truncateFiles = { throw CoreDataError.deleteFailed("Permission denied") }
    }

    await store.send(.truncateFilesButtonTapped)

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Storage Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Failed to truncate files local data.")
      }
    }
  }

  @MainActor
  @Test("ShowError action creates alert state")
  func showErrorCreatesAlert() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    }

    await store.send(.showError(.keychainError(operation: "read"))) {
      $0.alert = AlertState {
        TextState("Security Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Failed to read secure data.")
      }
    }
  }

  @MainActor
  @Test("Alert dismiss clears alert state")
  func alertDismissClearsState() async throws {
    var state = DiagnosticFeature.State()
    state.alert = AlertState {
      TextState("Test")
    } actions: {
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    }

    await store.send(.alert(.dismiss)) {
      $0.alert = nil
    }
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has empty keychain items")
  func initialStateEmpty() async throws {
    let state = DiagnosticFeature.State()
    #expect(state.keychainItems.isEmpty)
    #expect(state.showDebugActions == false)
    #expect(state.isLoading == false)
    #expect(state.alert == nil)
  }

  // MARK: - KeychainItem Tests

  @MainActor
  @Test("KeychainItem ID is name")
  func keychainItemId() async throws {
    let item = KeychainItem(name: "Token", displayValue: "value", itemType: .token)
    #expect(item.id == "Token")
  }

  @MainActor
  @Test("KeychainItem types are correct")
  func keychainItemTypes() async throws {
    let tokenItem = KeychainItem(name: "Token", displayValue: "v", itemType: .token)
    let userItem = KeychainItem(name: "User", displayValue: "v", itemType: .userData)
    let deviceItem = KeychainItem(name: "Device", displayValue: "v", itemType: .deviceData)

    #expect(tokenItem.itemType == .token)
    #expect(userItem.itemType == .userData)
    #expect(deviceItem.itemType == .deviceData)
  }
}
