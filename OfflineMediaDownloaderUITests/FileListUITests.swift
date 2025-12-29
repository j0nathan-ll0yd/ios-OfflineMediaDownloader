import XCTest

/// UI Tests for the file list and file operations
/// Note: The app supports guest browsing - file list is shown immediately on launch.
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
  func testFileListAppearsOnLaunch() throws {
    app.launch()

    // File list should appear on launch (guest browsing mode)
    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15), "File list should be visible on launch")
  }

  @MainActor
  func testFileListHasNavigationTitle() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Check for navigation title
    let navBar = app.navigationBars["Files"]
    XCTAssertTrue(navBar.exists, "Navigation bar with title 'Files' should exist")
  }

  // MARK: - Toolbar Tests

  @MainActor
  func testRefreshButtonExists() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Check for refresh button in toolbar
    let refreshButton = app.buttons[UITestHelpers.AccessibilityID.refreshButton]
    XCTAssertTrue(refreshButton.exists, "Refresh button should exist in toolbar")
  }

  @MainActor
  func testAddFileButtonExists() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Check for add button in toolbar
    let addButton = app.buttons[UITestHelpers.AccessibilityID.addFileButton]
    XCTAssertTrue(addButton.exists, "Add file button should exist in toolbar")
    XCTAssertTrue(addButton.isHittable, "Add file button should be tappable")
  }

  @MainActor
  func testAddButtonShowsConfirmationDialog() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Tap add button
    let addButton = app.buttons[UITestHelpers.AccessibilityID.addFileButton]
    addButton.tap()

    // Should show confirmation dialog
    let dialogTitle = app.staticTexts["Add Video"]
    XCTAssertTrue(dialogTitle.waitForExistence(timeout: 5), "Add Video dialog should appear")

    // Dismiss the dialog
    let cancelButton = app.buttons["Cancel"]
    if cancelButton.exists {
      cancelButton.tap()
    }
  }

  // MARK: - Tab Navigation Tests

  @MainActor
  func testTabBarNavigation() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Navigate to Account tab
    let accountTab = app.tabBars.buttons["Account"]
    let filesTab = app.tabBars.buttons["Files"]

    XCTAssertTrue(accountTab.exists, "Account tab should exist")
    XCTAssertTrue(filesTab.exists, "Files tab should exist")

    // Go to Account
    accountTab.tap()

    // Navigate back to Files
    filesTab.tap()

    // Verify file list is still visible
    XCTAssertTrue(fileList.exists, "Should return to file list view")
  }

  // MARK: - Empty State Tests

  @MainActor
  func testEmptyStateShowsPrompt() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Empty state shows "No files yet" message
    // This may or may not appear depending on whether the user has files
    let emptyText = app.staticTexts["No files yet"]
    if emptyText.exists {
      // Verify the hint text is also present
      let hintText = app.staticTexts["Tap + to add a video from your clipboard"]
      XCTAssertTrue(hintText.exists, "Empty state hint should be visible")
    }
    // If files exist, that's also a valid state
  }

  // MARK: - Pull to Refresh Tests

  @MainActor
  func testPullToRefreshWorks() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Find a cell or the list itself to pull down on
    let list = app.tables.firstMatch
    if list.exists {
      // Perform pull to refresh gesture
      let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
      let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
      start.press(forDuration: 0.1, thenDragTo: end)

      // Wait a moment for refresh to complete
      sleep(2)

      // List should still be visible
      XCTAssertTrue(fileList.exists, "File list should still be visible after refresh")
    }
  }
}
