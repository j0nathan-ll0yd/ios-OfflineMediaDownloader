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
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.getJwtToken = { testToken }
      $0.keychainClient.getUserData = { TestData.sampleUser }
      $0.keychainClient.getDeviceData = { TestData.sampleDevice }
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = [
        KeychainItem(name: "Token", displayValue: testToken + "...", itemType: .token),
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
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = [
        KeychainItem(name: "Token", displayValue: testToken + "...", itemType: .token)
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
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

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
    var deleteTokenCalled = false
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "Token", displayValue: "test...", itemType: .token),
      KeychainItem(name: "UserData", displayValue: "Test User", itemType: .userData)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteJwtToken = { deleteTokenCalled = true }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.keychainItemDeleted)
    #expect(deleteTokenCalled == true)
  }

  @MainActor
  @Test("Delete user data removes from keychain and list")
  func deleteUserData() async throws {
    var deleteUserDataCalled = false
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "UserData", displayValue: "Test User", itemType: .userData)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteUserData = { deleteUserDataCalled = true }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.keychainItemDeleted)
    #expect(deleteUserDataCalled == true)
  }

  @MainActor
  @Test("Delete device data removes from keychain and list")
  func deleteDeviceData() async throws {
    var deleteDeviceDataCalled = false
    var state = DiagnosticFeature.State()
    state.keychainItems = [
      KeychainItem(name: "DeviceData", displayValue: "arn:aws:sns:test", itemType: .deviceData)
    ]

    let store = TestStore(initialState: state) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.deleteDeviceData = { deleteDeviceDataCalled = true }
    }

    await store.send(.deleteKeychainItem(IndexSet(integer: 0))) {
      $0.keychainItems.remove(at: 0)
    }

    await store.receive(\.keychainItemDeleted)
    #expect(deleteDeviceDataCalled == true)
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
    var truncateCalled = false

    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.coreDataClient.truncateFiles = { truncateCalled = true }
    }

    await store.send(.truncateFilesButtonTapped)
    await store.receive(\.filesTruncated)

    #expect(truncateCalled == true)
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state has empty keychain items")
  func initialStateEmpty() async throws {
    let state = DiagnosticFeature.State()
    #expect(state.keychainItems.isEmpty)
    #expect(state.showDebugActions == false)
    #expect(state.isLoading == false)
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
