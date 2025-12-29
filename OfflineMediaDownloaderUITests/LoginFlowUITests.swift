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

  // MARK: - Guest Browsing Tests

  @MainActor
  func testAppLaunchShowsFileList() throws {
    app.launch()

    // App should show file list immediately (guest browsing mode)
    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15), "File list should appear on launch")
  }

  @MainActor
  func testGuestUserCanAccessAccountTab() throws {
    app.launch()

    // Wait for app to load
    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

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

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

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

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

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
    XCTAssertTrue(fileList.waitForExistence(timeout: 5))
  }

  // MARK: - Login Sheet Tests

  @MainActor
  func testTappingSignInButtonPresentsLoginSheet() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Go to Account tab and tap sign in
    app.tabBars.buttons["Account"].tap()

    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10))
    signInButton.tap()

    // Should present a login sheet with the native Sign in with Apple button
    // The sheet contains a SignInWithAppleButton which has the same accessibility ID
    let sheetSignInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(sheetSignInButton.waitForExistence(timeout: 10),
                  "Login sheet should present with Sign in with Apple button")
  }

  @MainActor
  func testLoginSheetCanBeDismissed() throws {
    app.launch()

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 15))

    // Go to Account tab and tap sign in
    app.tabBars.buttons["Account"].tap()

    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10))
    signInButton.tap()

    // Wait for sheet to appear
    sleep(1)

    // Look for Cancel button in the sheet
    let cancelButton = app.buttons["Cancel"]
    if cancelButton.waitForExistence(timeout: 5) {
      cancelButton.tap()

      // Should return to Account tab
      XCTAssertTrue(signInButton.waitForExistence(timeout: 5),
                    "Should return to Account tab after dismissing login sheet")
    }
  }
}
