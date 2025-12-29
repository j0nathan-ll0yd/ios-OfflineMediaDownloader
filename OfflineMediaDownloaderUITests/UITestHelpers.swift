import XCTest

/// UI Test helper utilities for E2E testing
enum UITestHelpers {

  // MARK: - Launch Configuration

  /// Configure app for UI testing with stubbed network responses
  static func configureForUITesting(_ app: XCUIApplication, stubMode: StubMode = .enabled) {
    // Enable UI test mode
    app.launchEnvironment["UI_TEST_MODE"] = "true"

    // Configure stub mode
    switch stubMode {
    case .enabled:
      app.launchEnvironment["STUB_NETWORK"] = "true"
    case .localStack:
      app.launchEnvironment["LOCALSTACK_ENABLED"] = "true"
    case .disabled:
      break
    }

    // Disable animations for faster tests
    app.launchEnvironment["DISABLE_ANIMATIONS"] = "true"

    // Reset state for clean test runs
    app.launchArguments.append("--reset-state")
  }

  /// Configure app with a pre-authenticated user session
  static func configureWithAuthenticatedSession(_ app: XCUIApplication) {
    app.launchEnvironment["STUB_AUTH_STATE"] = "authenticated"
    app.launchEnvironment["STUB_JWT_TOKEN"] = "test-jwt-token-ui-test"
    app.launchEnvironment["STUB_USER_ID"] = "ui-test-user-001"
  }

  /// Configure app with specific stub responses
  static func configureStubResponses(_ app: XCUIApplication, responses: StubResponses) {
    if responses.hasFiles {
      app.launchEnvironment["STUB_FILE_LIST"] = "populated"
    } else {
      app.launchEnvironment["STUB_FILE_LIST"] = "empty"
    }

    if responses.loginSuccess {
      app.launchEnvironment["STUB_LOGIN_RESULT"] = "success"
    } else {
      app.launchEnvironment["STUB_LOGIN_RESULT"] = "failure"
    }

    if responses.downloadSuccess {
      app.launchEnvironment["STUB_DOWNLOAD_RESULT"] = "success"
    } else {
      app.launchEnvironment["STUB_DOWNLOAD_RESULT"] = "failure"
    }
  }

  // MARK: - Types

  enum StubMode {
    case enabled     // Use in-app stub responses
    case localStack  // Use LocalStack backend
    case disabled    // Use real backend (staging)
  }

  struct StubResponses {
    var hasFiles: Bool = true
    var loginSuccess: Bool = true
    var downloadSuccess: Bool = true

    static let success = StubResponses()
    static let emptyFiles = StubResponses(hasFiles: false)
    static let loginFailure = StubResponses(loginSuccess: false)
    static let downloadFailure = StubResponses(downloadSuccess: false)
  }

  // MARK: - Wait Helpers

  /// Wait for an element to exist with timeout
  static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
    element.waitForExistence(timeout: timeout)
  }

  /// Wait for an element to disappear
  static func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
    return result == .completed
  }

  // MARK: - Accessibility Identifiers

  /// Standard accessibility identifiers used in the app
  enum AccessibilityID {
    // Login
    static let signInWithAppleButton = "signInWithAppleButton"
    static let skipLoginButton = "skipLoginButton"

    // File List
    static let fileListView = "fileListView"
    static let fileCell = "fileCell"
    static let refreshButton = "refreshButton"
    static let addFileButton = "addFileButton"

    // File Cell
    static let downloadButton = "downloadButton"
    static let playButton = "playButton"
    static let deleteButton = "deleteButton"
    static let downloadProgress = "downloadProgress"

    // Tab Bar
    static let filesTab = "filesTab"
    static let diagnosticsTab = "diagnosticsTab"

    // Alerts
    static let errorAlert = "errorAlert"
    static let confirmationAlert = "confirmationAlert"

    // Loading
    static let loadingIndicator = "loadingIndicator"
  }
}

// MARK: - XCUIApplication Extension

extension XCUIApplication {
  /// Launch the app configured for UI testing
  func launchForUITesting(stubMode: UITestHelpers.StubMode = .enabled) {
    UITestHelpers.configureForUITesting(self, stubMode: stubMode)
    launch()
  }

  /// Launch the app with an authenticated session
  func launchWithAuthenticatedSession(stubMode: UITestHelpers.StubMode = .enabled) {
    UITestHelpers.configureForUITesting(self, stubMode: stubMode)
    UITestHelpers.configureWithAuthenticatedSession(self)
    launch()
  }

  /// Launch with specific stub configuration
  func launchWithStubs(_ responses: UITestHelpers.StubResponses, stubMode: UITestHelpers.StubMode = .enabled) {
    UITestHelpers.configureForUITesting(self, stubMode: stubMode)
    UITestHelpers.configureStubResponses(self, responses: responses)
    launch()
  }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
  /// Tap element if it exists
  func tapIfExists(timeout: TimeInterval = 5) -> Bool {
    if waitForExistence(timeout: timeout) {
      tap()
      return true
    }
    return false
  }

  /// Type text and dismiss keyboard
  func typeTextAndDismiss(_ text: String) {
    tap()
    typeText(text)
    typeText("\n")
  }
}
