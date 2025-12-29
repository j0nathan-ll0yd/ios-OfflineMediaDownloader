import XCTest

/// UI Tests for the login/authentication flow
/// Note: The app supports guest browsing - users can browse files without signing in.
/// Sign in with Apple is available from the Account tab for authenticated features.
final class LoginFlowUITests: XCTestCase {

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

  // MARK: - Guest Browsing Tests

  @MainActor
  func testAppLaunchShowsFileList() throws {
    app.launch()

    // App should show file list immediately (guest browsing mode)
    // Verify by checking for the "Files" navigation bar
    XCTAssertTrue(waitForFileListToAppear(), "File list should appear on launch")
  }

  @MainActor
  func testGuestUserCanAccessAccountTab() throws {
    app.launch()

    // Wait for app to load
    XCTAssertTrue(waitForFileListToAppear())

    // Navigate to Account tab
    let accountTab = app.tabBars.buttons["Account"]
    XCTAssertTrue(accountTab.exists, "Account tab should exist")
    accountTab.tap()

    // Should see sign in prompt for unauthenticated users
    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10),
                  "Sign in with Apple button should be visible on Account tab for guests")
  }

  @MainActor
  func testSignInButtonExistsOnAccountTab() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Go to Account tab
    app.tabBars.buttons["Account"].tap()

    // Verify Sign in with Apple button exists
    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10))
    XCTAssertTrue(signInButton.isHittable, "Sign in button should be tappable")
  }

  // MARK: - Tab Navigation Tests

  @MainActor
  func testTabBarNavigationBetweenFilesAndAccount() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Navigate to Account tab
    let accountTab = app.tabBars.buttons["Account"]
    let filesTab = app.tabBars.buttons["Files"]

    accountTab.tap()

    // Verify we're on Account tab
    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

    // Navigate back to Files tab
    filesTab.tap()

    // Verify we're back on file list
    XCTAssertTrue(waitForFileListToAppear(timeout: 5))
  }

  // MARK: - Login Sheet Tests

  @MainActor
  func testTappingSignInButtonPresentsLoginSheet() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Go to Account tab and tap sign in
    app.tabBars.buttons["Account"].tap()

    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10))
    signInButton.tap()

    // Should present a login sheet with the native Sign in with Apple button
    // Look for the Cancel button that appears in the sheet
    let cancelButton = app.buttons["Cancel"]
    XCTAssertTrue(cancelButton.waitForExistence(timeout: 10),
                  "Login sheet should present with Cancel button")
  }

  @MainActor
  func testLoginSheetCanBeDismissed() throws {
    app.launch()

    XCTAssertTrue(waitForFileListToAppear())

    // Go to Account tab and tap sign in
    app.tabBars.buttons["Account"].tap()

    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10))
    signInButton.tap()

    // Wait for sheet to appear - look for Cancel button
    let cancelButton = app.buttons["Cancel"]
    XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))

    cancelButton.tap()

    // Should return to Account tab
    XCTAssertTrue(signInButton.waitForExistence(timeout: 5),
                  "Should return to Account tab after dismissing login sheet")
  }
}
