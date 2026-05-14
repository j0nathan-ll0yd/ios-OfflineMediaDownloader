import APIClient
import ComposableArchitecture
import DefaultFilesFeature
import FileCellFeature
import FileClient
@testable import FileListFeature
import Foundation
import LoggerClient
import OrderedCollections
import PasteboardClient
import PersistenceClient
import ServerClient
import SharedModels
import Testing

@Suite(.serialized)
struct FileListFeatureTests {
  // MARK: - Loading Tests

  @MainActor
  @Test("onAppear loads files from CoreData with loading indicator on first load")
  func onAppearLoadsFiles() async {
    let state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true } // User is authenticated
    state.$isRegistered.withLock { $0 = true } // Prevent auto-refresh (only unregistered users auto-refresh)

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.coreDataClient.getFiles = { TestData.multipleFiles }
    }

    // files are empty at onAppear time so isLoading stays true (no state change)
    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded) {
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
      $0.hasCompletedInitialLoad = true
      $0.isLoading = false
    }
  }

  @MainActor
  @Test("Local files preserve download state on reload")
  func preserveDownloadStateOnReload() async {
    var state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true } // User is authenticated
    state.$isRegistered.withLock { $0 = true } // Prevent auto-refresh (only unregistered users auto-refresh)
    var existingCellState = FileCellFeature.State(file: TestData.sampleFile)
    existingCellState.isDownloaded = true
    existingCellState.downloadProgress = 1.0
    state.files = [existingCellState]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.coreDataClient.getFiles = { [TestData.sampleFile] }
    }

    // files are pre-populated so onAppear sets isLoading = files.isEmpty = false
    await store.send(.onAppear) {
      $0.isLoading = false
    }

    await store.receive(\.localFilesLoaded) {
      $0.hasCompletedInitialLoad = true
    }

    // Verify download state is preserved after the receive
    let finalFiles = store.state.files
    #expect(finalFiles[id: TestData.sampleFile.fileId]?.isDownloaded == true)
    #expect(finalFiles[id: TestData.sampleFile.fileId]?.downloadProgress == 1.0)
  }

  // MARK: - Refresh Tests

  @MainActor
  @Test("Refresh fetches from server and caches")
  func refreshFetchesFromServer() async {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    // isLoading is already true (default), hasCompletedInitialLoad is false — no state change on send
    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
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
  func refreshRemovesPendingIds() async {
    var state = FileListFeature.State()
    state.pendingFileIds = [TestData.sampleFile.fileId, "other-pending-id"]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    // isLoading is already true (default), hasCompletedInitialLoad is false — no state change on send
    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
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
  func networkErrorShowsAlert() async {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in throw TestData.TestNetworkError.notConnected }
    }

    // isLoading is already true (default), hasCompletedInitialLoad is false — no state change on send
    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.failure) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
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
  func unauthorizedTriggersDel() async {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in throw ServerClientError.unauthorized(requestId: "test-request-id", correlationId: "test-correlation-id") }
    }

    // isLoading is already true (default), hasCompletedInitialLoad is false — no state change on send
    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.failure) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
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
  func serverErrorShowsAlert() async {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in throw ServerClientError.internalServerError(
        message: "Database unavailable",
        requestId: "test-request-id",
        correlationId: "test-correlation-id"
      ) }
    }

    // isLoading is already true (default), hasCompletedInitialLoad is false — no state change on send
    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.failure) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
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
  func showErrorCreatesAlert() async {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
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
  @Test("Alert dismiss clears alert and pending state")
  func alertDismissClearsState() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")
    state.pendingYoutubeId = "test-id"
    state.alert = AlertState {
      TextState("Test")
    } actions: {
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.alert(.presented(.dismiss))) {
      $0.alert = nil
      $0.pendingAddUrl = nil
      $0.pendingYoutubeId = nil
    }
  }

  @MainActor
  @Test("Alert retry triggers refresh")
  func alertRetryTriggersRefresh() async {
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
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.alert(.presented(.retryRefresh))) {
      $0.alert = nil
    }

    // isLoading is already true (default), hasCompletedInitialLoad is false — no state change on receive
    await store.receive(\.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
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
  func addButtonShowsConfirmation() async {
    let state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addButtonTapped) {
      $0.showAddConfirmation = true
    }

    await store.send(.confirmationDismissed) {
      $0.showAddConfirmation = false
    }
  }

  @MainActor
  @Test("Add file success starts LiveActivity when youtubeId is pending")
  func addFileSuccessStartsLiveActivity() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")
    state.pendingYoutubeId = "youtube-video-id"

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addFileResponse(.success(TestData.validAddFileResponse))) {
      $0.pendingAddUrl = nil
      $0.pendingYoutubeId = nil
    }

    // LiveActivity starts only after successful response
    await store.receive(\.addPendingFileId) {
      $0.pendingFileIds = ["youtube-video-id"]
    }
  }

  @MainActor
  @Test("Add file success without youtubeId does not start LiveActivity")
  func addFileSuccessNoLiveActivity() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://example.com/file.mp4")
    // No pendingYoutubeId

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addFileResponse(.success(TestData.validAddFileResponse))) {
      $0.pendingAddUrl = nil
    }
    // No addPendingFileId received - no LiveActivity
  }

  @MainActor
  @Test("Add file auth error triggers delegate and clears pending state")
  func addFileAuthError() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")
    state.pendingYoutubeId = "test-id"

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addFileResponse(.failure(ServerClientError.unauthorized(requestId: "test-request-id", correlationId: "test-correlation-id")))) {
      $0.pendingAddUrl = nil
      $0.pendingYoutubeId = nil
    }
    await store.receive(\.delegate.authenticationRequired)
  }

  @MainActor
  @Test("Add file server error shows inline alert (non-retryable)")
  func addFileServerError() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")
    state.pendingYoutubeId = "test-id"

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addFileResponse(.failure(ServerClientError.internalServerError(
      message: "Invalid URL",
      requestId: "test-request-id",
      correlationId: "test-correlation-id"
    )))) {
      // Inline alert wired to retryAddFile (server errors are non-retryable, so OK-only)
      $0.alert = AlertState {
        TextState("Server Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Invalid URL\n\nCorrelation ID: test-correlation-id\nRequest ID: test-request-id")
      }
      // Pending state preserved for potential future retry
    }
  }

  @MainActor
  @Test("Add file network error shows alert with retryAddFile action")
  func addFileNetworkErrorShowsRetryAlert() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")
    state.pendingYoutubeId = "test-id"

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addFileResponse(.failure(TestData.TestNetworkError.notConnected))) {
      $0.alert = AlertState {
        TextState("No Connection")
      } actions: {
        ButtonState(action: .retryAddFile) {
          TextState("Retry")
        }
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Please check your internet connection and try again.")
      }
      // Pending state preserved for retry
    }
  }

  @MainActor
  @Test("Retry add file after failure succeeds and starts LiveActivity")
  func retryAddFileSucceedsWithLiveActivity() async {
    var state = FileListFeature.State()
    state.pendingAddUrl = URL(string: "https://youtube.com/watch?v=test")
    state.pendingYoutubeId = "test-id"
    state.alert = AlertState {
      TextState("No Connection")
    } actions: {
      ButtonState(action: .retryAddFile) {
        TextState("Retry")
      }
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.addFile = { _ in TestData.validAddFileResponse }
    }

    await store.send(.alert(.presented(.retryAddFile))) {
      $0.alert = nil
    }

    await store.receive(\.addFileResponse.success) {
      $0.pendingAddUrl = nil
      $0.pendingYoutubeId = nil
    }

    // LiveActivity starts after successful retry
    await store.receive(\.addPendingFileId) {
      $0.pendingFileIds = ["test-id"]
    }
  }

  @MainActor
  @Test("prepareAddFile sets pending URL and youtubeId")
  func prepareAddFileSetsState() async throws {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    let url = try #require(URL(string: "https://youtube.com/watch?v=abc123"))
    await store.send(.prepareAddFile(url: url, youtubeId: "abc123")) {
      $0.pendingAddUrl = url
      $0.pendingYoutubeId = "abc123"
    }
  }

  // MARK: - Push Notification Actions

  @MainActor
  @Test("File added from push inserts and sorts by date")
  func fileAddedFromPushSorted() async {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.downloadedFile)]

    // New file with more recent date
    var newFile = TestData.sampleFile
    newFile.publishDate = Date() // Now

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
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
  func fileAddedRemovesPending() async {
    var state = FileListFeature.State()
    state.pendingFileIds = [TestData.sampleFile.fileId, "other-id"]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
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
  func fileAddedUpdatesExisting() async {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    var updatedFile = TestData.sampleFile
    updatedFile.title = "Updated Title"

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
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

    let newUrl = try #require(URL(string: "https://example.com/new-url.mp4"))

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.updateFileUrl(fileId: pendingFile.fileId, url: newUrl)) {
      $0.files[id: pendingFile.fileId]?.file.url = newUrl
      $0.files[id: pendingFile.fileId]?.isServerDownloading = false
    }
  }

  @MainActor
  @Test("Refresh file state triggers onAppear for specific cell")
  func refreshFileState() async {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
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
  @Test("Delete files shows confirmation then removes on confirm")
  func deleteFilesShowsConfirmationThenRemoves() async {
    let fileToDelete = TestData.multipleFiles[0]
    var state = FileListFeature.State()
    state.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
      FileCellFeature.State(file: $0)
    })

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.deleteFile = { _ in
        DeleteFileResponse(
          body: DeleteFileResponseDetail(deleted: true, fileRemoved: true),
          error: nil,
          requestId: "test"
        )
      }
      $0.coreDataClient.deleteFile = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in }
    }

    await store.send(.deleteFiles(IndexSet(integer: 0))) {
      $0.fileToDelete = fileToDelete
      $0.showDeleteConfirmation = true
    }

    await store.send(.confirmDeleteFile) {
      $0.files.remove(id: fileToDelete.fileId)
      $0.fileToDelete = nil
      $0.showDeleteConfirmation = false
    }
  }

  @MainActor
  @Test("Delete files can be dismissed")
  func deleteFilesDismissed() async {
    let fileToDelete = TestData.multipleFiles[0]
    var state = FileListFeature.State()
    state.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
      FileCellFeature.State(file: $0)
    })

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.deleteFiles(IndexSet(integer: 0))) {
      $0.fileToDelete = fileToDelete
      $0.showDeleteConfirmation = true
    }

    await store.send(.dismissDeleteConfirmation) {
      $0.fileToDelete = nil
      $0.showDeleteConfirmation = false
    }
  }

  @MainActor
  @Test("Delete files failure reinserts and shows alert")
  func deleteFilesFailureReinserts() async {
    let fileToDelete = TestData.multipleFiles[0]
    var state = FileListFeature.State()
    state.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
      FileCellFeature.State(file: $0)
    })

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.deleteFile = { _ in throw ServerClientError.unauthorized(requestId: nil, correlationId: nil) }
      $0.coreDataClient.deleteFile = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.thumbnailCacheClient.deleteThumbnail = { _ in }
    }

    await store.send(.deleteFiles(IndexSet(integer: 0))) {
      $0.fileToDelete = fileToDelete
      $0.showDeleteConfirmation = true
    }

    await store.send(.confirmDeleteFile) {
      $0.files.remove(id: fileToDelete.fileId)
      $0.fileToDelete = nil
      $0.showDeleteConfirmation = false
    }

    await store.receive(\.deleteFileFailed) {
      $0.files.append(FileCellFeature.State(file: fileToDelete))
      $0.files.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
      $0.alert = AlertState {
        TextState("Delete Failed")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Failed to delete \"\(fileToDelete.title ?? fileToDelete.key)\": Session expired - please login again")
      }
    }
  }

  // MARK: - Video Playback Tests

  @MainActor
  @Test("Play file delegate sets playing file")
  func playFileDelegate() async {
    var state = FileListFeature.State()
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.analytics.track = { _, _ in }
      $0.date = .constant(fixedDate)
      $0.coreDataClient.incrementPlayCount = {}
    }

    await store.send(.files(.element(id: TestData.sampleFile.fileId, action: .delegate(.playFile(TestData.sampleFile))))) {
      $0.isPreparingToPlay = true
    }

    await store.receive(\.startPlayer) {
      $0.playingFile = TestData.sampleFile
      $0.playbackStartTime = fixedDate
    }
  }

  @MainActor
  @Test("Dismiss player clears playing file")
  func dismissPlayerClears() async {
    var state = FileListFeature.State()
    state.playingFile = TestData.sampleFile

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.dismissPlayer) {
      $0.playingFile = nil
    }
  }

  // MARK: - Pending File ID Deduplication Tests

  @MainActor
  @Test("addPendingFileId is idempotent — duplicate ID is not appended")
  func addPendingFileIdIdempotent() async {
    var state = FileListFeature.State()
    state.pendingFileIds = ["existing-id"]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.addPendingFileId("existing-id"))

    // pendingFileIds should still contain exactly one entry (OrderedSet no-ops on duplicate)
    #expect(store.state.pendingFileIds == OrderedSet(["existing-id"]))
    #expect(store.state.pendingFileIds.count == 1)
  }

  @MainActor
  @Test("fileFailed removes fileId from pendingFileIds")
  func fileFailedRemovesPendingId() async {
    var state = FileListFeature.State()
    state.pendingFileIds = ["failing-id", "other-id"]
    state.files = [FileCellFeature.State(file: TestData.sampleFile)]

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.fileFailed(fileId: "failing-id", error: "Server error")) {
      $0.pendingFileIds = ["other-id"]
      $0.alert = AlertState {
        TextState("Download Failed")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Server error")
      }
    }
  }

  @MainActor
  @Test("fileFailed for unknown pending ID is safe no-op on pendingFileIds")
  func fileFailedUnknownPendingId() async {
    let state = FileListFeature.State()
    // pendingFileIds is empty

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.fileFailed(fileId: "unknown-id", error: "Error")) {
      // pendingFileIds remains empty (remove is a no-op)
      $0.alert = AlertState {
        TextState("Download Failed")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Error")
      }
    }
  }

  // MARK: - Initial Load State Tests

  @MainActor
  @Test("Unregistered user with empty local files stays loading until remote response arrives")
  func onAppear_unregisteredEmptyLocal_staysLoadingUntilRemote() async {
    let store = TestStore(initialState: FileListFeature.State()) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.coreDataClient.getFiles = { [] }
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded)

    await store.receive(\.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
    }

    await store.receive(\.defaultFiles.parentProvidedFile) {
      $0.defaultFiles.isLoadingFile = false
      $0.defaultFiles.file = TestData.multipleFiles.first
    }
  }

  @MainActor
  @Test("Registered user with cached files completes initial load immediately from CoreData")
  func onAppear_registeredWithCachedFiles_loadsImmediately() async {
    let state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.coreDataClient.getFiles = { TestData.multipleFiles }
    }

    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded) {
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
      $0.hasCompletedInitialLoad = true
      $0.isLoading = false
    }
  }

  @MainActor
  @Test("After initial load, refreshButtonTapped sets isRefreshing instead of isLoading")
  func refreshAfterInitialLoad_setsRefreshing_notLoading() async {
    let state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.coreDataClient.getFiles = { TestData.multipleFiles }
      $0.serverClient.getFiles = { _ in TestData.validFileResponse }
      $0.coreDataClient.cacheFiles = { _ in }
    }

    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded) {
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
      $0.hasCompletedInitialLoad = true
      $0.isLoading = false
    }

    await store.send(.refreshButtonTapped) {
      $0.isRefreshing = true
    }

    await store.receive(\.remoteFilesResponse.success) {
      $0.isRefreshing = false
      $0.files = IdentifiedArray(uniqueElements: TestData.multipleFiles.map {
        FileCellFeature.State(file: $0)
      })
    }
  }

  @MainActor
  @Test("Registered but unauthenticated user: refreshButtonTapped exits loading state before auth delegate")
  func refreshButtonTapped_registeredUnauthenticated_exitsLoadingState() async {
    let state = FileListFeature.State()
    state.$isRegistered.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
    }

    await store.send(.refreshButtonTapped) {
      $0.hasCompletedInitialLoad = true
      $0.isLoading = false
    }

    await store.receive(\.delegate.authenticationRequired)
  }

  @MainActor
  @Test("Registered user with empty local files shows empty state (not skeleton) after CoreData load")
  func onAppear_registeredEmptyLocal_showsEmptyStateNotSkeleton() async {
    let state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.coreDataClient.getFiles = { [] }
    }

    await store.send(.onAppear)

    await store.receive(\.localFilesLoaded) {
      $0.hasCompletedInitialLoad = true
      $0.isLoading = false
    }
  }

  // MARK: - Merge Behavior Tests

  @MainActor
  @Test("Remote response merges with local downloaded files instead of replacing")
  func remoteFilesResponseMergesWithLocalDownloaded() async {
    let localOnlyFile = File(
      fileId: "local-only",
      key: "LocalVideo.mp4",
      publishDate: Date(timeIntervalSince1970: 1_700_000_000),
      size: 500_000,
      url: URL(string: "https://example.com/local.mp4")
    )
    var localCell = FileCellFeature.State(file: localOnlyFile)
    localCell.isDownloaded = true

    var state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }
    state.files = [localCell]

    let serverResponse = FileResponse(
      body: FileList(contents: TestData.multipleFiles, keyCount: 3),
      error: nil,
      requestId: "request-merge-test"
    )

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in serverResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.analytics.track = { _, _ in }
    }

    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
      var expected = IdentifiedArrayOf<FileCellFeature.State>()
      for file in TestData.multipleFiles {
        expected.append(FileCellFeature.State(file: file))
      }
      expected.append(localCell)
      expected.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
      $0.files = expected
    }
  }

  @MainActor
  @Test("Remote response preserves local files missing from server regardless of download status")
  func remoteFilesResponsePreservesLocalFiles() async {
    let nonDownloadedFile = File(
      fileId: "non-downloaded",
      key: "OldVideo.mp4",
      publishDate: Date(timeIntervalSince1970: 1_600_000_000),
      size: 200_000,
      url: URL(string: "https://example.com/old.mp4")
    )
    let nonDownloadedCell = FileCellFeature.State(file: nonDownloadedFile)

    var state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }
    state.files = [nonDownloadedCell]

    let serverResponse = FileResponse(
      body: FileList(contents: TestData.multipleFiles, keyCount: 3),
      error: nil,
      requestId: "request-remove-test"
    )

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in serverResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.analytics.track = { _, _ in }
    }

    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
      var expected = IdentifiedArrayOf<FileCellFeature.State>()
      for file in TestData.multipleFiles {
        expected.append(FileCellFeature.State(file: file))
      }
      expected.append(nonDownloadedCell)
      expected.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
      $0.files = expected
    }
  }

  @MainActor
  @Test("Remote response updates metadata for files existing both locally and on server")
  func remoteFilesResponseUpdatesMetadata() async {
    let outdatedFile = File(
      fileId: TestData.sampleFile.fileId,
      key: "OldName.mp4",
      publishDate: TestData.sampleFile.publishDate,
      size: 100_000,
      url: URL(string: "https://example.com/old-name.mp4")
    )
    var outdatedCell = FileCellFeature.State(file: outdatedFile)
    outdatedCell.isDownloaded = true
    outdatedCell.downloadProgress = 1.0

    var state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }
    state.files = [outdatedCell]

    let serverResponse = FileResponse(
      body: FileList(contents: [TestData.sampleFile], keyCount: 1),
      error: nil,
      requestId: "request-update-test"
    )

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in serverResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
      var updatedCell = FileCellFeature.State(file: TestData.sampleFile)
      updatedCell.isDownloaded = true
      updatedCell.downloadProgress = 1.0
      $0.files = [updatedCell]
    }
  }

  @MainActor
  @Test("Remote response adds new server files not in local state")
  func remoteFilesResponseAddsNewFiles() async {
    var state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }
    state.files = []

    let serverResponse = FileResponse(
      body: FileList(contents: TestData.multipleFiles, keyCount: 3),
      error: nil,
      requestId: "request-add-test"
    )

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in serverResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
    }

    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
      var expected = IdentifiedArrayOf<FileCellFeature.State>()
      for file in TestData.multipleFiles {
        expected.append(FileCellFeature.State(file: file))
      }
      expected.sort { ($0.file.publishDate ?? .distantPast) > ($1.file.publishDate ?? .distantPast) }
      $0.files = expected
    }
  }

  @MainActor
  @Test("Remote response maintains sort order by publishDate descending")
  func remoteFilesResponseMaintainsSortOrder() async {
    let oldFile = File(
      fileId: "old-local",
      key: "Old.mp4",
      publishDate: Date(timeIntervalSince1970: 1_600_000_000),
      size: 100_000,
      url: URL(string: "https://example.com/old.mp4")
    )
    var oldCell = FileCellFeature.State(file: oldFile)
    oldCell.isDownloaded = true

    var state = FileListFeature.State()
    state.$isAuthenticated.withLock { $0 = true }
    state.$isRegistered.withLock { $0 = true }
    state.files = [oldCell]

    let newFile = File(
      fileId: "new-server",
      key: "New.mp4",
      publishDate: Date(timeIntervalSince1970: 1_800_000_000),
      size: 300_000,
      url: URL(string: "https://example.com/new.mp4")
    )
    let serverResponse = FileResponse(
      body: FileList(contents: [newFile], keyCount: 1),
      error: nil,
      requestId: "request-sort-test"
    )

    let store = TestStore(initialState: state) {
      FileListFeature()
    } withDependencies: {
      $0.logger = TestData.noopLogger
      $0.pasteboardClient = TestData.noopPasteboardClient
      $0.serverClient.getFiles = { _ in serverResponse }
      $0.coreDataClient.cacheFiles = { _ in }
      $0.fileClient.fileExists = { _ in false }
      $0.analytics.track = { _, _ in }
    }

    await store.send(.refreshButtonTapped)

    await store.receive(\.remoteFilesResponse.success) {
      $0.isLoading = false
      $0.hasCompletedInitialLoad = true
      $0.isRefreshing = false
      let newCell = FileCellFeature.State(file: newFile)
      $0.files = [newCell, oldCell]
    }
  }
}
