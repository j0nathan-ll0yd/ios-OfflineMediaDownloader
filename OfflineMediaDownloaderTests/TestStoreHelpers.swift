import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

// MARK: - Common Dependency Presets

/// Extension to configure common test dependencies
extension DependencyValues {
  /// Configures a silent logger that does nothing
  mutating func configureSilentLogger() {
    self.logger.log = { _, _, _, _, _, _ in }
  }

  /// Configures keychain with no stored values
  mutating func configureEmptyKeychain() {
    self.keychainClient.getJwtToken = { nil }
    self.keychainClient.getUserIdentifier = { nil }
    self.keychainClient.getDeviceData = { nil }
    self.keychainClient.getTokenExpiresAt = { nil }
  }

  /// Configures keychain with a valid authenticated user
  mutating func configureAuthenticatedKeychain(token: String = TestData.validJwtToken) {
    self.keychainClient.getJwtToken = { token }
    self.keychainClient.setJwtToken = { _ in }
    self.keychainClient.deleteJwtToken = { }
    self.keychainClient.getUserIdentifier = { TestData.sampleUser.identifier }
    self.keychainClient.getUserData = { TestData.sampleUser }
    self.keychainClient.setUserData = { _ in }
    self.keychainClient.getTokenExpiresAt = { nil }
    self.keychainClient.setTokenExpiresAt = { _ in }
    self.keychainClient.deleteTokenExpiresAt = { }
  }

  /// Configures file client that reports no files exist
  mutating func configureEmptyFileSystem() {
    self.fileClient.fileExists = { _ in false }
    self.fileClient.deleteFile = { _ in }
  }

  /// Configures file client that reports all files exist
  mutating func configureAllFilesExist() {
    self.fileClient.fileExists = { _ in true }
    self.fileClient.deleteFile = { _ in }
  }

  /// Configures CoreData client with empty data
  mutating func configureEmptyCoreData() {
    self.coreDataClient.getFiles = { [] }
    self.coreDataClient.cacheFiles = { _ in }
    self.coreDataClient.cacheFile = { _ in }
    self.coreDataClient.deleteFile = { _ in }
  }

  /// Configures CoreData client with sample files
  mutating func configureCoreDataWithFiles(_ files: [File] = TestData.multipleFiles) {
    self.coreDataClient.getFiles = { files }
    self.coreDataClient.cacheFiles = { _ in }
    self.coreDataClient.cacheFile = { _ in }
    self.coreDataClient.deleteFile = { _ in }
    self.coreDataClient.incrementPlayCount = { }
  }

  /// Configures server client for successful file fetch
  mutating func configureSuccessfulFileServer() {
    self.serverClient.getFiles = { _ in TestData.validFileResponse }
    self.serverClient.addFile = { _ in TestData.validAddFileResponse }
  }

  /// Configures thumbnail cache client with no-op operations
  mutating func configureThumbnailCache() {
    self.thumbnailCacheClient.deleteThumbnail = { _ in }
    self.thumbnailCacheClient.getThumbnail = { _, _ in nil }
    self.thumbnailCacheClient.hasCachedThumbnail = { _ in false }
    self.thumbnailCacheClient.clearCache = { }
  }

  /// Applies all common test configurations at once
  mutating func configureForTesting() {
    configureSilentLogger()
    configureEmptyKeychain()
    configureEmptyFileSystem()
    configureEmptyCoreData()
    configureThumbnailCache()
  }
}

// MARK: - TestStore Builder Helpers

/// Namespace for test store creation helpers
enum TestStoreFactory {

  // MARK: - FileListFeature Stores

  /// Creates a FileListFeature store with authenticated user state
  @MainActor
  static func authenticatedFileList(
    files: [File] = [],
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<FileListFeature> {
    var state = FileListFeature.State()
    state.isAuthenticated = true
    state.isRegistered = true
    state.files = IdentifiedArray(uniqueElements: files.map { FileCellFeature.State(file: $0) })

    return TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.configureForTesting()
      $0.configureCoreDataWithFiles(files.isEmpty ? TestData.multipleFiles : files)
      $0.configureSuccessfulFileServer()
      configure?(&$0)
    }
  }

  /// Creates a FileListFeature store for unauthenticated user
  @MainActor
  static func unauthenticatedFileList(
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<FileListFeature> {
    let state = FileListFeature.State()

    return TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.configureForTesting()
      configure?(&$0)
    }
  }

  // MARK: - RootFeature Stores

  /// Creates a RootFeature store for authenticated user
  @MainActor
  static func authenticatedRoot(
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<RootFeature> {
    var state = RootFeature.State()
    state.isAuthenticated = true
    state.main = MainFeature.State()
    state.main.isAuthenticated = true
    state.main.fileList.isAuthenticated = true

    return TestStore(initialState: state) {
      RootFeature()
    } withDependencies: {
      $0.configureForTesting()
      $0.configureAuthenticatedKeychain()
      configure?(&$0)
    }
  }

  /// Creates a RootFeature store for unauthenticated user
  @MainActor
  static func unauthenticatedRoot(
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<RootFeature> {
    return TestStore(initialState: RootFeature.State()) {
      RootFeature()
    } withDependencies: {
      $0.configureForTesting()
      configure?(&$0)
    }
  }

  // MARK: - MainFeature Stores

  /// Creates a MainFeature store with default state
  @MainActor
  static func mainFeature(
    isAuthenticated: Bool = false,
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<MainFeature> {
    var state = MainFeature.State()
    state.isAuthenticated = isAuthenticated
    state.fileList.isAuthenticated = isAuthenticated

    return TestStore(initialState: state) {
      MainFeature()
    } withDependencies: {
      $0.configureForTesting()
      if isAuthenticated {
        $0.configureAuthenticatedKeychain()
      }
      configure?(&$0)
    }
  }

  // MARK: - LoginFeature Stores

  /// Creates a LoginFeature store with default state
  @MainActor
  static func loginFeature(
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<LoginFeature> {
    return TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.configureForTesting()
      configure?(&$0)
    }
  }

  // MARK: - FileCellFeature Stores

  /// Creates a FileCellFeature store with a sample file
  @MainActor
  static func fileCell(
    file: File = TestData.sampleFile,
    isDownloaded: Bool = false,
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<FileCellFeature> {
    var state = FileCellFeature.State(file: file)
    state.isDownloaded = isDownloaded

    return TestStore(initialState: state) {
      FileCellFeature()
    } withDependencies: {
      $0.configureForTesting()
      configure?(&$0)
    }
  }

  // MARK: - ActiveDownloadsFeature Stores

  /// Creates an ActiveDownloadsFeature store with optional active downloads
  @MainActor
  static func activeDownloads(
    downloads: [ActiveDownloadsFeature.ActiveDownload] = [],
    configure: ((inout DependencyValues) -> Void)? = nil
  ) -> TestStoreOf<ActiveDownloadsFeature> {
    var state = ActiveDownloadsFeature.State()
    state.activeDownloads = IdentifiedArray(uniqueElements: downloads)

    return TestStore(initialState: state) {
      ActiveDownloadsFeature()
    } withDependencies: {
      $0.configureForTesting()
      configure?(&$0)
    }
  }
}

// MARK: - Test Timing Utilities

/// Timing trait for tests that may take longer (under 1 minute)
/// Use for integration-style tests or tests with multiple async steps
let standardTest = Testing.TimeLimitTrait.timeLimit(.minutes(1))

/// Timing trait for slower tests (under 2 minutes)
/// Use for tests that involve significant setup or many assertions
let slowTest = Testing.TimeLimitTrait.timeLimit(.minutes(2))

// MARK: - Test Measurement Helpers

/// Measures execution time of a test block and logs it
/// Useful for identifying slow tests during development
@MainActor
func measureTest(
  _ label: String,
  threshold: Duration = .seconds(1),
  operation: () async throws -> Void
) async throws {
  let clock = ContinuousClock()
  let start = clock.now
  try await operation()
  let elapsed = clock.now - start

  if elapsed > threshold {
    // Log slow tests for identification
    print("⚠️ SLOW TEST: \(label) took \(elapsed)")
  }
}

// MARK: - Common Test State Builders

/// Helpers for building common test states
enum TestStates {

  /// Creates an authenticated MainFeature state
  static func authenticatedMain() -> MainFeature.State {
    var state = MainFeature.State()
    state.isAuthenticated = true
    state.isRegistered = true
    state.fileList.isAuthenticated = true
    state.fileList.isRegistered = true
    return state
  }

  /// Creates a FileListFeature state with sample files
  static func fileListWithFiles(_ files: [File] = TestData.multipleFiles) -> FileListFeature.State {
    var state = FileListFeature.State()
    state.isAuthenticated = true
    state.isRegistered = true
    state.files = IdentifiedArray(uniqueElements: files.map { FileCellFeature.State(file: $0) })
    return state
  }

  /// Creates a FileCellFeature state for a downloaded file
  static func downloadedFileCell(file: File = TestData.downloadedFile) -> FileCellFeature.State {
    var state = FileCellFeature.State(file: file)
    state.isDownloaded = true
    state.downloadProgress = 1.0
    return state
  }

  /// Creates a FileCellFeature state for a downloading file
  static func downloadingFileCell(
    file: File = TestData.sampleFile,
    progress: Double = 0.5
  ) -> FileCellFeature.State {
    var state = FileCellFeature.State(file: file)
    state.isDownloading = true
    state.downloadProgress = progress
    return state
  }

  /// Creates an ActiveDownload item for testing
  static func activeDownload(
    fileId: String = "test-file",
    title: String = "Test Video.mp4",
    progress: Int = 50,
    status: ActiveDownloadsFeature.ActiveDownload.DownloadStatus = .downloading,
    isBackgroundInitiated: Bool = false
  ) -> ActiveDownloadsFeature.ActiveDownload {
    ActiveDownloadsFeature.ActiveDownload(
      fileId: fileId,
      title: title,
      progress: progress,
      status: status,
      isBackgroundInitiated: isBackgroundInitiated
    )
  }
}
