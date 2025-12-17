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
      $0.serverClient.loginUser = { _ in
        LoginResponse(body: TokenResponse(token: "test-jwt-token"), error: nil, requestId: "123")
      }
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
    state.pendingUserData = UserData(
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
    }

    await store.send(.didFinishLaunching) {
      $0.isLaunching = false
    }

    await store.receive(\.loginStatusResponse) {
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

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    await store.receive(\.localFilesLoaded) {
      $0.isLoading = false
      $0.files = []
    }
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
      $0.coreDataClient.saveContext = { }
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
  @Test("Download button starts download")
  func downloadButtonStartsDownload() async throws {
    let testFile = TestHelper.getDefaultFile()

    let store = TestStore(initialState: FileCellFeature.State(file: testFile)) {
      FileCellFeature()
    }

    await store.send(.downloadButtonTapped) {
      $0.isDownloading = true
    }

    await store.receive(\.downloadProgressUpdated) {
      $0.downloadProgress = 1.0
      $0.isDownloading = false
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
  @Test("Play button does not change state")
  func playButtonNoStateChange() async throws {
    let testFile = TestHelper.getDefaultFile()

    let store = TestStore(initialState: FileCellFeature.State(file: testFile)) {
      FileCellFeature()
    }

    await store.send(.playButtonTapped)
  }
}

// MARK: - DiagnosticFeature Tests

@Suite("DiagnosticFeature Tests")
struct DiagnosticFeatureTests {

  @MainActor
  @Test("onAppear loads keychain items")
  func onAppearLoadsKeychainItems() async throws {
    let store = TestStore(initialState: DiagnosticFeature.State()) {
      DiagnosticFeature()
    } withDependencies: {
      $0.keychainClient.getJwtToken = { "test-token" }
      $0.keychainClient.getUserData = {
        UserData(email: "test@test.com", firstName: "Test", identifier: "123", lastName: "User")
      }
      $0.keychainClient.getDeviceData = { nil }
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }

    await store.receive(\.keychainItemsLoaded) {
      $0.isLoading = false
      $0.keychainItems = [
        KeychainItem(name: "Token", displayValue: "test-token...", itemType: .token),
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
