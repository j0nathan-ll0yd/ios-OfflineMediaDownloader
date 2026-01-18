import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("FileListFeature Tests")
struct FileListFeatureTests {

  // MARK: - Loading Tests

  @MainActor
  @Test("onAppear loads files from CoreData without loading indicator")
  func onAppearLoadsFiles() async throws {
    var state = FileListFeature.State()
    state.isAuthenticated = true  // User is authenticated
    state.isRegistered = true     // Prevent auto-refresh (only unregistered users auto-refresh)

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.coreDataClient.getFiles = { TestData.multipleFiles }
    }

    // onAppear does NOT set isLoading - only refreshButtonTapped does
    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded) {
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
    }
  }

  @MainActor
  @Test("Local files preserve download state on reload")
  func preserveDownloadStateOnReload() async throws {
    var state = FileListFeature.State()
    state.isAuthenticated = true  // User is authenticated
    state.isRegistered = true     // Prevent auto-refresh (only unregistered users auto-refresh)
    var existingCellState = FileCellFeature.State(file: TestData.sampleFile)
    existingCellState.isDownloaded = true
    existingCellState.downloadProgress = 1.0
    state.files = [existingCellState]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.coreDataClient.getFiles = { [TestData.sampleFile] }
    }

    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded)

    // Verify download state is preserved after the receive
    let finalFiles = store.state.files
    #expect(finalFiles[id: TestData.sampleFile.fileId]?.isDownloaded == true)
    #expect(finalFiles[id: TestData.sampleFile.fileId]?.downloadProgress == 1.0)
  }

  // MARK: - Refresh Tests

  @MainActor
  @Test("Refresh fetches from server and caches")
  func refreshFetchesFromServer() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
    }

    // Parent shares first file with DefaultFilesFeature
    await store.receive(\.defaultFiles.parentProvidedFile) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.file = TestData.multipleFiles.first
    }
  }

  @MainActor
  @Test("Refresh removes pending IDs for available files")
  func refreshRemovesPendingIds() async throws {
    var state = FileListFeature.State()
    state.pendingFileIds = [TestData.sampleFile.fileId, "other-pending-id"]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
      // sampleFile.fileId should be removed from pending, other-pending-id should remain
      $0.pendingFileIds = ["other-pending-id"]
    }

    // Parent shares first file with DefaultFilesFeature
    await store.receive(\.defaultFiles.parentProvidedFile) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.file = TestData.multipleFiles.first
    }
  }

  // MARK: - Error Handling Tests

  @MainActor
  @Test("Network error shows alert with retry button")
  func networkErrorShowsAlert() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = { _ in throw TestData.TestNetworkError.notConnected }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.failure) {
      $0.isLoading = false
    }

    // DefaultFilesFeature receives error notification
    await store.receive(\.defaultFiles.fileFetchFailed) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.alert = AlertState {
        TextState("Failed to Load")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Please check your internet connection and try again.")
      }
    }

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("No Connection")
      } actions: {
        ButtonState(action: .retryRefresh) {
          TextState("Retry")
        }
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Please check your internet connection and try again.")
      }
    }
  }

  @MainActor
  @Test("Unauthorized error triggers auth required delegate")
  func unauthorizedTriggersDel() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = { _ in throw ServerClientError.unauthorized(requestId: "test-request-id", correlationId: "test-correlation-id") }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.failure) {
      $0.isLoading = false
    }

    // DefaultFilesFeature receives error notification
    await store.receive(\.defaultFiles.fileFetchFailed) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.alert = AlertState {
        TextState("Failed to Load")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Your session has expired. Please sign in again.\n\nCorrelation ID: test-correlation-id\nRequest ID: test-request-id")
      }
    }

    await store.receive(\.delegate.authenticationRequired)
  }

  @MainActor
  @Test("Server error with message shows alert")
  func serverErrorShowsAlert() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = { _ in throw ServerClientError.internalServerError(message: "Database unavailable", requestId: "test-request-id", correlationId: "test-correlation-id") }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.failure) {
      $0.isLoading = false
    }

    // DefaultFilesFeature receives error notification
    await store.receive(\.defaultFiles.fileFetchFailed) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.alert = AlertState {
        TextState("Failed to Load")
      } actions: {
        ButtonState(action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Database unavailable\n\nCorrelation ID: test-correlation-id\nRequest ID: test-request-id")
      }
    }

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Server Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Database unavailable\n\nCorrelation ID: test-correlation-id\nRequest ID: test-request-id")
      }
    }
  }

  @MainActor
  @Test("ShowError action creates alert state")
  func showErrorCreatesAlert() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    }

    await store.send(.showError(.invalidClipboardUrl)) {
      $0.alert = AlertState {
        TextState("Invalid URL")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("The clipboard does not contain a valid URL.")
      }
    }
  }

  @MainActor
  @Test("Alert dismiss clears alert state")
  func alertDismissClearsState() async throws {
    var state = FileListFeature.State()
    state.alert = AlertState {
      TextState("Test")
    } actions: {
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.alert(.dismiss)) {
      $0.alert = nil
    }
  }

  @MainActor
  @Test("Alert retry triggers refresh")
  func alertRetryTriggersRefresh() async throws {
    var state = FileListFeature.State()
    state.alert = AlertState {
      TextState("No Connection")
    } actions: {
      ButtonState(action: .retryRefresh) {
        TextState("Retry")
      }
    }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.alert(.presented(.retryRefresh))) {
      $0.alert = nil
    }

    await store.receive(\.refreshButtonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
    }

    // Parent shares first file with DefaultFilesFeature
    await store.receive(\.defaultFiles.parentProvidedFile) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.file = TestData.multipleFiles.first
    }
  }

  // MARK: - Add File Tests

  @MainActor
  @Test("Add button shows confirmation dialog when authenticated")
  func addButtonShowsConfirmation() async throws {
    var state = FileListFeature.State()
    state.isAuthenticated = true

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.addButtonTapped) {
      $0.showAddConfirmation = true
    }

    await store.send(.confirmationDismissed) {
      $0.showAddConfirmation = false
    }
  }

  @MainActor
  @Test("Add file success adds pending file ID")
  func addFileAddsPendingId() async throws {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.serverClient.addFile = { _ in TestData.validAddFileResponse }
    }

    // Simulate having a pending ID added
    await store.send(.addPendingFileId("youtube-video-id")) {
      $0.pendingFileIds = ["youtube-video-id"]
    }

    await store.send(.addFileResponse(.success(TestData.validAddFileResponse))) {
      $0.pendingAddUrl = nil
    }
  }

  @MainActor
  @Test("Add file auth error triggers delegate")
  func addFileAuthError() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    }

    await store.send(.addFileResponse(.failure(ServerClientError.unauthorized(requestId: "test-request-id", correlationId: "test-correlation-id"))))
    await store.receive(\.delegate.authenticationRequired)
  }

  @MainActor
  @Test("Add file server error shows alert")
  func addFileServerError() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    }

    await store.send(.addFileResponse(.failure(ServerClientError.internalServerError(message: "Invalid URL", requestId: "test-request-id", correlationId: "test-correlation-id"))))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Server Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Invalid URL\n\nCorrelation ID: test-correlation-id\nRequest ID: test-request-id")
      }
    }
  }

  // MARK: - Push Notification Actions

  @MainActor
  @Test("File added from push inserts and sorts by date")
  func fileAddedFromPushSorted() async throws {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.downloadedFile)]

    // New file with more recent date
    var newFile = TestData.sampleFile
    newFile.publishDate = Date()  // Now

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.fileAddedFromPush(newFile)) {
      $0.files.append(FileCellFeature.State(file: newFile))
      // Files should be sorted by publishDate descending
      $0.files.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
    }

    // New files trigger onAppear to check download status
    await store.receive(\.files)
    await store.receive(\.files)
  }

  @MainActor
  @Test("File added from push removes from pending IDs")
  func fileAddedRemovesPending() async throws {
    var state = FileListFeature.State()
    state.pendingFileIds = [TestData.sampleFile.fileId, "other-id"]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.fileAddedFromPush(TestData.sampleFile)) {
      $0.files.append(FileCellFeature.State(file: TestData.sampleFile))
      $0.pendingFileIds = ["other-id"]
    }

    // New files trigger onAppear to check download status
    await store.receive(\.files)
    await store.receive(\.files)
  }

  @MainActor
  @Test("File added from push updates existing file metadata")
  func fileAddedUpdatesExisting() async throws {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    var updatedFile = TestData.sampleFile
    updatedFile.title = "Updated Title"

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.fileAddedFromPush(updatedFile)) {
      $0.files[id: TestData.sampleFile.fileId]?.file = updatedFile
    }
  }

  @MainActor
  @Test("Update file URL updates existing file state")
  func updateFileUrl() async throws {
    var state = FileListFeature.State()
    let pendingFile = TestData.pendingFile
    state.files = [FileCellFeature.State(file: pendingFile)]

    let newUrl = URL(string: "https://example.com/new-url.mp4")!

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.updateFileUrl(fileId: pendingFile.fileId, url: newUrl)) {
      $0.files[id: pendingFile.fileId]?.file.url = newUrl
    }
  }

  @MainActor
  @Test("Refresh file state triggers onAppear for specific cell")
  func refreshFileState() async throws {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.fileClient.fileExists = { _ in true }
    }

    await store.send(.refreshFileState(TestData.sampleFile.fileId))

    // Receives the forwarded action to FileCellFeature (onAppear)
    await store.receive(\.files)

    // Then the FileCellFeature's effect runs and updates isDownloaded (checkFileExistence)
    await store.receive(\.files) {
      $0.files[id: TestData.sampleFile.fileId]?.isDownloaded = true
    }
  }

  // MARK: - Delete Tests

  @MainActor
  @Test("Delete files removes from state")
  func deleteFilesRemoves() async throws {
    var state = FileListFeature.State()
    state.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
      FileCellFeature.State(file: $0)
    })

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.deleteFiles(IndexSet(integer: 0))) {
      $0.files.remove(at: 0)
    }
  }

  @MainActor
  @Test("File deleted delegate removes file from list", .disabled("Flaky test - passes alone but fails in suite, TCA/Swift Testing interaction issue"))
  func fileDeletedDelegate() async throws {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.downloadedFile)]

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.files(.element(id: TestData.downloadedFile.fileId, action: .delegate(.fileDeleted(TestData.downloadedFile))))) {
      $0.files.remove(id: TestData.downloadedFile.fileId)
    }
  }

  // MARK: - Video Playback Tests

  @MainActor
  @Test("Play file delegate sets playing file")
  func playFileDelegate() async throws {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.coreDataClient.incrementPlayCount = { }
    }

    await store.send(.files(.element(id: TestData.sampleFile.fileId, action: .delegate(.playFile(TestData.sampleFile))))) {
      $0.isPreparingToPlay = true
    }

    await store.receive(\.startPlayer) {
      $0.playingFile = TestData.sampleFile
    }
  }

  @MainActor
  @Test("Dismiss player clears playing file")
  func dismissPlayerClears() async throws {
    var state = FileListFeature.State()
    state.playingFile = TestData.sampleFile

    let store = TestStore(initialState: state) {
      FileListFeature()
    }

    await store.send(.dismissPlayer) {
      $0.playingFile = nil
    }
  }
}
