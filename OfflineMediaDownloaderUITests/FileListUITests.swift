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

  // MARK: - Helper to verify file list is displayed

  private func waitForFileListToAppear(timeout: TimeInterval = 15) -> Bool {
    // File list is identified by the "Files" navigation bar
    let navBar = app.navigationBars["Files"]
    return navBar.waitForExistence(timeout: timeout)
  }

  // MARK: - File List Display Tests

  @MainActor
  func testFileListAppearsOnLaunch() throws {
    app.launch()

    // File list should appear on launch (guest browsing mode)
    XCTAssertTrue(waitForFileListToAppear(), "File list should be visible on launch")
  }

  @MainActor
  func testFileListHasNavigationTitle() throws {
    app.launch()

    // Check for navigation title
    let navBar = app.navigationBars["Files"]
    XCTAssertTrue(navBar.waitForExistence(timeout: 15), "Navigation bar with title 'Files' should exist")
  }

  // MARK: - Toolbar Tests

  @MainActor
  func testRefreshButtonExists() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Check for refresh button in toolbar
    let refreshButton = app.buttons[UITestHelpers.AccessibilityID.refreshButton]
    XCTAssertTrue(refreshButton.waitForExistence(timeout: 5), "Refresh button should exist in toolbar")
  }

  @MainActor
  func testAddFileButtonExists() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Check for add button in toolbar
    let addButton = app.buttons[UITestHelpers.AccessibilityID.addFileButton]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add file button should exist in toolbar")
    XCTAssertTrue(addButton.isHittable, "Add file button should be tappable")
  }

  @MainActor
  func testAddButtonShowsConfirmationDialog() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Tap add button
    let addButton = app.buttons[UITestHelpers.AccessibilityID.addFileButton]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    addButton.tap()

    // Should show confirmation dialog with "Add Video" title
    // Look for the "From Clipboard" button which is unique to this dialog
    let clipboardButton = app.buttons["From Clipboard"]
    XCTAssertTrue(clipboardButton.waitForExistence(timeout: 5), "Add Video dialog should appear")

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

    XCTAssertTrue(waitForFileListToAppear())

    // Navigate to Account tab
    let accountTab = app.tabBars.buttons["Account"]
    let filesTab = app.tabBars.buttons["Files"]

    XCTAssertTrue(accountTab.exists, "Account tab should exist")
    XCTAssertTrue(filesTab.exists, "Files tab should exist")

    // Go to Account
    accountTab.tap()

    // Wait for Account tab content
    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

    // Navigate back to Files
    filesTab.tap()

    // Verify file list is still visible
    XCTAssertTrue(waitForFileListToAppear(timeout: 5), "Should return to file list view")
  }

  // MARK: - Empty State Tests

  @MainActor
  func testEmptyStateShowsPrompt() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Empty state shows "No files yet" message
    // This may or may not appear depending on whether the user has files
    let emptyText = app.staticTexts["No files yet"]
    if emptyText.waitForExistence(timeout: 3) {
      // Verify the hint text is also present
      let hintText = app.staticTexts["Tap + to add a video from your clipboard"]
      XCTAssertTrue(hintText.exists, "Empty state hint should be visible")
    }
    // If files exist, that's also a valid state - test passes
  }

  // MARK: - Pull to Refresh Tests

  @MainActor
  func testPullToRefreshWorks() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Find the navigation bar area to pull down from
    let navBar = app.navigationBars["Files"]

    // Get coordinates for pull gesture
    let start = navBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3.0))
    let end = navBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 6.0))

    // Perform pull to refresh gesture
    start.press(forDuration: 0.1, thenDragTo: end)

    // Wait a moment for refresh to complete
    sleep(2)

    // List should still be visible
    XCTAssertTrue(waitForFileListToAppear(timeout: 5), "File list should still be visible after refresh")
  }
}
