import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

// MARK: - LoginFeature Tests

@Suite("LoginFeature Tests")
struct LoginFeatureTests {

  @MainActor
  @Test("Login success stores token and notifies delegate")
  func loginSuccess() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.keychainClient.setJwtToken = { _ in }
    }

    await store.send(.loginResponse(.success(LoginResponse(
      body: TokenResponse(token: "test-jwt-token"),
      error: nil,
      requestId: "123"
    )))) {
      $0.loginStatus = .authenticated
    }

    await store.receive(\.delegate.loginCompleted)
  }

  @MainActor
  @Test("Login failure sets error message")
  func loginFailure() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    struct TestError: Error, LocalizedError {
      var errorDescription: String? { "Test error" }
    }

    await store.send(.loginResponse(.failure(TestError()))) {
      $0.errorMessage = "Test error"
    }
  }

  @MainActor
  @Test("Registration success stores token, user data, and notifies delegate")
  func registrationSuccess() async throws {
    var state = LoginFeature.State()
    state.pendingUserData = User(
      email: "test@example.com",
      firstName: "Test",
      identifier: "user-123",
      lastName: "User"
    )

    let store = TestStore(initialState: state) {
      LoginFeature()
    } withDependencies: {
      $0.keychainClient.setJwtToken = { _ in }
      $0.keychainClient.setUserData = { _ in }
    }

    await store.send(.registrationResponse(.success(LoginResponse(
      body: TokenResponse(token: "test-jwt-token"),
      error: nil,
      requestId: "123"
    )))) {
      $0.registrationStatus = .registered
      $0.loginStatus = .authenticated
    }

    await store.receive(\.delegate.registrationCompleted)
  }

  @MainActor
  @Test("Login response with nil body sets error message")
  func loginResponseNilBody() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    await store.send(.loginResponse(.success(LoginResponse(
      body: nil,
      error: nil,
      requestId: "123"
    )))) {
      $0.errorMessage = "Invalid response: missing token"
    }
  }
}

// MARK: - RootFeature Tests

@Suite("RootFeature Tests")
struct RootFeatureTests {

  @MainActor
  @Test("didFinishLaunching sets up app and checks login status")
  func didFinishLaunching() async throws {
    let store = TestStore(initialState: RootFeature.State()) {
      RootFeature()
    } withDependencies: {
      $0.authenticationClient.determineLoginStatus = { .unauthenticated }
      $0.keychainClient.getUserIdentifier = { nil }
    }

    await store.send(.didFinishLaunching) {
      $0.launchStatus = "Checking authentication..."
    }

    await store.receive(\.loginStatusResponse) {
      $0.isLaunching = false
      $0.isAuthenticated = false
    }
  }

  @MainActor
  @Test("Login completion from child sets authenticated state")
  func loginCompletionSetsAuthenticated() async throws {
    let store = TestStore(initialState: RootFeature.State()) {
      RootFeature()
    }

    await store.send(.login(.delegate(.loginCompleted))) {
      $0.isAuthenticated = true
      $0.main = MainFeature.State()
    }
  }

  @MainActor
  @Test("Device registration stores endpoint ARN")
  func deviceRegistration() async throws {
    let store = TestStore(initialState: RootFeature.State()) {
      RootFeature()
    } withDependencies: {
      $0.serverClient.registerDevice = { _ in
        RegisterDeviceResponse(
          body: EndpointResponse(endpointArn: "arn:aws:sns:test"),
          error: nil,
          requestId: "123"
        )
      }
      $0.keychainClient.setDeviceData = { _ in }
    }

    await store.send(.didRegisterForRemoteNotificationsWithDeviceToken("test-token"))
    await store.receive(\.deviceRegistrationResponse.success)
  }
}

// MARK: - MainFeature Tests

@Suite("MainFeature Tests")
struct MainFeatureTests {

  @MainActor
  @Test("Tab selection updates selected tab")
  func tabSelection() async throws {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    }

    await store.send(.tabSelected(.account)) {
      $0.selectedTab = .account
    }

    await store.send(.tabSelected(.files)) {
      $0.selectedTab = .files
    }
  }
}

// MARK: - FileListFeature Tests

@Suite("FileListFeature Tests")
struct FileListFeatureTests {

  @MainActor
  @Test("onAppear loads files from CoreData")
  func onAppearLoadsFiles() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.coreDataClient.getFiles = { [] }
    }

    // onAppear does NOT set isLoading - only refreshButtonTapped does
    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded)
  }

  @MainActor
  @Test("Refresh fetches from server")
  func refreshFetchesFromServer() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = {
        FileResponse(body: FileList(contents: [], keyCount: 0), error: nil, requestId: "123")
      }
      $0.coreDataClient.cacheFiles = { _ in }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
    }
  }

  @MainActor
  @Test("Add button shows confirmation dialog")
  func addButtonShowsConfirmation() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    }

    await store.send(.addButtonTapped) {
      $0.showAddConfirmation = true
    }

    await store.send(.confirmationDismissed) {
      $0.showAddConfirmation = false
    }
  }
}

// MARK: - FileCellFeature Tests

@Suite("FileCellFeature Tests")
struct FileCellFeatureTests {

  @MainActor
  @Test("onAppear checks file existence")
  func onAppearChecksFileExistence() async throws {
    let testFile = TestHelper.getDefaultFile()

    let store = TestStore(initialState: FileCellFeature.State(file: testFile)) {
      FileCellFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.onAppear)

    await store.receive(\.checkFileExistence) {
      $0.isDownloaded = true
    }
  }

  @MainActor
  @Test("Delete button triggers file deletion")
  func deleteButtonTriggersFileDeletion() async throws {
    let testFile = TestHelper.getDefaultFile()

    let store = TestStore(initialState: FileCellFeature.State(file: testFile)) {
      FileCellFeature()
    } withDependencies: {
      $0.coreDataClient.deleteFile = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.deleteButtonTapped)
    await store.receive(\.delegate.fileDeleted)
  }

  @MainActor
  @Test("Play button sends delegate action")
  func playButtonSendsDelegate() async throws {
    let testFile = TestHelper.getDefaultFile()

    let store = TestStore(initialState: FileCellFeature.State(file: testFile)) {
      FileCellFeature()
    }

    await store.send(.playButtonTapped)
    await store.receive(\.delegate.playFile)
  }
}

// MARK: - DiagnosticFeature Tests

@Suite("DiagnosticFeature Tests")
struct DiagnosticFeatureTests {

  @MainActor
  @Test("onAppear loads keychain items")
  func onAppearLoadsKeychainItems() async throws {
    // Token is truncated to prefix(50) + "..." in DiagnosticFeature
    let testToken = "test-token-012345678901234567890123456789012345678"  // 50 chars exactly
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.getJwtToken = { testToken }
      $0.keychainClient.getUserData = {
        User(email: "test@test.com", firstName: "Test", identifier: "123", lastName: "User")
      }
      $0.keychainClient.getDeviceData = { nil }
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = [
        KeychainItem(name: "Token", displayValue: testToken + "...", itemType: .token),
        KeychainItem(name: "UserData", displayValue: "Test User (test@test.com)", itemType: .userData)
      ]
    }
  }

  @MainActor
  @Test("Toggle debug mode shows/hides debug actions")
  func toggleDebugMode() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    }

    await store.send(.toggleDebugMode) {
      $0.showDebugActions = true
    }

    await store.send(.toggleDebugMode) {
      $0.showDebugActions = false
    }
  }

  @MainActor
  @Test("Truncate files calls coreDataClient")
  func truncateFiles() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.coreDataClient.truncateFiles = { }
    }

    await store.send(.truncateFilesButtonTapped)
    await store.receive(\.filesTruncated)
  }
}
