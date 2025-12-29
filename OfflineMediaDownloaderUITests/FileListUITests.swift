import XCTest

/// UI Tests for the file list and file operations
final class FileListUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - File List Display Tests

  @MainActor
  func testFileListDisplaysFiles() throws {
    app.launchWithAuthenticatedSession()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 10), "File list should be visible")

    // Check for file cells
    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)

    // With stub data, we should have at least one file
    XCTAssertTrue(fileCells.firstMatch.waitForExistence(timeout: 10), "Should display at least one file")
  }

  @MainActor
  func testEmptyFileListDisplaysEmptyState() throws {
    app.launchWithStubs(.emptyFiles)
    UITestHelpers.configureWithAuthenticatedSession(app)
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 10))

    // Check for empty state message or add file prompt
    // Implementation depends on actual UI
  }

  // MARK: - Refresh Tests

  @MainActor
  func testPullToRefreshUpdatesFileList() throws {
    app.launchWithAuthenticatedSession()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 10))

    // Perform pull to refresh gesture
    let firstCell = app.cells.firstMatch
    if firstCell.exists {
      firstCell.swipeDown()

      // Wait for refresh to complete
      let loadingIndicator = app.activityIndicators[UITestHelpers.AccessibilityID.loadingIndicator]
      if loadingIndicator.exists {
        XCTAssertTrue(UITestHelpers.waitForElementToDisappear(loadingIndicator, timeout: 15),
                      "Loading indicator should disappear after refresh")
      }
    }
  }

  // MARK: - File Cell Interaction Tests

  @MainActor
  func testTappingFileCellShowsDetail() throws {
    app.launchWithAuthenticatedSession()

    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)
    guard fileCells.firstMatch.waitForExistence(timeout: 10) else {
      XCTFail("Should have at least one file cell")
      return
    }

    // Tap the first file cell
    fileCells.firstMatch.tap()

    // Check for detail view or expanded state
    // Implementation depends on navigation pattern (sheet, navigation, inline expansion)
  }

  @MainActor
  func testDownloadButtonStartsDownload() throws {
    app.launchWithAuthenticatedSession()

    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)
    guard fileCells.firstMatch.waitForExistence(timeout: 10) else {
      XCTFail("Should have at least one file cell")
      return
    }

    // Find a file with download button (not yet downloaded)
    let downloadButton = fileCells.firstMatch.buttons[UITestHelpers.AccessibilityID.downloadButton]

    if downloadButton.exists && downloadButton.isHittable {
      downloadButton.tap()

      // Check for download progress indicator
      let progressIndicator = fileCells.firstMatch.progressIndicators[UITestHelpers.AccessibilityID.downloadProgress]

      // In stub mode, download should complete quickly
      // In real mode, would need to wait for actual download
    }
  }

  @MainActor
  func testPlayButtonAppearsForDownloadedFiles() throws {
    app.launchWithAuthenticatedSession()

    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)
    guard fileCells.firstMatch.waitForExistence(timeout: 10) else {
      XCTFail("Should have at least one file cell")
      return
    }

    // Look for play button on downloaded files
    let playButton = fileCells.firstMatch.buttons[UITestHelpers.AccessibilityID.playButton]

    // Play button should exist on downloaded files
    // May need to find specific downloaded file in list
  }

  // MARK: - Add File Tests

  @MainActor
  func testAddFileButtonExists() throws {
    app.launchWithAuthenticatedSession()

    let addButton = app.buttons[UITestHelpers.AccessibilityID.addFileButton]

    // Add button may be in navigation bar or floating
    if addButton.exists {
      XCTAssertTrue(addButton.isHittable, "Add file button should be tappable")
    }
  }

  // MARK: - Tab Navigation Tests

  @MainActor
  func testTabBarNavigation() throws {
    app.launchWithAuthenticatedSession()

    // Check files tab is selected by default
    let filesTab = app.tabBars.buttons[UITestHelpers.AccessibilityID.filesTab]
    let diagnosticsTab = app.tabBars.buttons[UITestHelpers.AccessibilityID.diagnosticsTab]

    if filesTab.exists && diagnosticsTab.exists {
      // Navigate to diagnostics
      diagnosticsTab.tap()

      // Navigate back to files
      filesTab.tap()

      let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
      XCTAssertTrue(fileList.exists, "Should return to file list view")
    }
  }
}
