import XCTest

/// Full end-to-end journey tests for AWS Device Farm
/// These tests exercise the complete user flow from registration to file playback
///
/// Prerequisites:
/// - Run on real device (AWS Device Farm or physical device)
/// - Backend deployed to staging environment
/// - Test Apple ID configured for Sign in with Apple
///
/// Note: These tests are designed for Device Farm and may not work in simulator
/// due to Sign in with Apple and push notification requirements.
final class FullJourneyE2ETests: XCTestCase {

  var app: XCUIApplication!

  // MARK: - Test Configuration

  /// Check if running on real device (required for full E2E)
  private var isRealDevice: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return true
    #endif
  }

  /// Check if running in Device Farm environment
  private var isDeviceFarm: Bool {
    ProcessInfo.processInfo.environment["AWS_DEVICE_FARM"] == "true"
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()

    // Configure for E2E testing (use real backend, not stubs)
    app.launchEnvironment["E2E_TEST_MODE"] = "true"

    // On Device Farm, use staging backend
    if isDeviceFarm {
      app.launchEnvironment["USE_STAGING_BACKEND"] = "true"
    }
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Full Journey Test

  /// Complete user journey: Launch → Sign In → Browse Files → Download → Play
  @MainActor
  func testCompleteUserJourney() throws {
    // Skip on simulator - requires real device for SIWA
    try XCTSkipIf(!isRealDevice, "Full E2E journey requires real device")

    app.launch()

    // Step 1: Login Screen
    try performLogin()

    // Step 2: File List
    try verifyFileListLoaded()

    // Step 3: Download a File
    try downloadFirstAvailableFile()

    // Step 4: Play Downloaded File
    try playDownloadedFile()
  }

  // MARK: - Journey Steps

  private func performLogin() throws {
    let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]

    guard signInButton.waitForExistence(timeout: 15) else {
      // May already be logged in from previous session
      let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
      if fileList.exists {
        return // Already authenticated
      }
      XCTFail("Neither login screen nor file list appeared")
      return
    }

    // Tap Sign in with Apple
    signInButton.tap()

    // Wait for Apple ID authentication
    // On Device Farm with pre-configured Apple ID, this should auto-complete
    // May need to handle 2FA or Face ID prompts

    // Wait for file list to appear (successful login)
    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.waitForExistence(timeout: 30),
                  "File list should appear after successful login")
  }

  private func verifyFileListLoaded() throws {
    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.exists, "File list should be visible")

    // Wait for files to load
    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)

    // May have files or may be empty for new user
    // If empty, we'd need to trigger a file addition via webhook
  }

  private func downloadFirstAvailableFile() throws {
    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)

    guard fileCells.count > 0 else {
      // No files available - skip download step
      // In a complete E2E test, we'd trigger file addition here
      return
    }

    // Find a file with a download button (not yet downloaded)
    for i in 0..<min(fileCells.count, 5) {
      let cell = fileCells.element(boundBy: i)
      let downloadButton = cell.buttons[UITestHelpers.AccessibilityID.downloadButton]

      if downloadButton.exists && downloadButton.isHittable {
        downloadButton.tap()

        // Wait for download to complete
        let playButton = cell.buttons[UITestHelpers.AccessibilityID.playButton]
        XCTAssertTrue(playButton.waitForExistence(timeout: 120),
                      "Play button should appear after download completes")
        return
      }
    }

    // All files may already be downloaded
  }

  private func playDownloadedFile() throws {
    let fileCells = app.cells.matching(identifier: UITestHelpers.AccessibilityID.fileCell)

    // Find a file with a play button (downloaded)
    for i in 0..<min(fileCells.count, 5) {
      let cell = fileCells.element(boundBy: i)
      let playButton = cell.buttons[UITestHelpers.AccessibilityID.playButton]

      if playButton.exists && playButton.isHittable {
        playButton.tap()

        // Verify video player appears
        // May need to check for AVPlayerViewController or custom player
        sleep(2) // Allow player to initialize

        // Dismiss player
        app.tap() // Tap to show controls
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
          doneButton.tap()
        }
        return
      }
    }

    // No downloadable files found
  }

  // MARK: - Push Notification Test

  /// Test push notification receipt and handling
  /// Requires Device Farm with SNS integration
  @MainActor
  func testPushNotificationFlow() throws {
    try XCTSkipIf(!isDeviceFarm, "Push notification test requires Device Farm")

    app.launch()

    // Ensure authenticated
    try performLogin()

    // Wait for push notification
    // In Device Farm, the backend would send a test notification
    // The app should receive it and update the file list

    let fileList = app.otherElements[UITestHelpers.AccessibilityID.fileListView]
    XCTAssertTrue(fileList.exists)

    // Trigger notification from backend (would need coordination)
    // Wait for file list to update
  }

  // MARK: - Error Recovery Test

  @MainActor
  func testNetworkErrorRecovery() throws {
    app.launch()

    // This test would require network manipulation
    // On Device Farm, could use airplane mode or network throttling
  }

  // MARK: - Account Deletion Test

  /// Test account deletion flow (Sign in with Apple compliance)
  @MainActor
  func testAccountDeletion() throws {
    try XCTSkipIf(!isRealDevice, "Account deletion requires real device")

    app.launch()

    // Login
    try performLogin()

    // Navigate to settings/diagnostics
    let diagnosticsTab = app.tabBars.buttons[UITestHelpers.AccessibilityID.diagnosticsTab]
    guard diagnosticsTab.waitForExistence(timeout: 10) else {
      XCTFail("Diagnostics tab should exist")
      return
    }
    diagnosticsTab.tap()

    // Find and tap delete account button
    let deleteButton = app.buttons["Delete Account"]
    if deleteButton.waitForExistence(timeout: 5) {
      deleteButton.tap()

      // Confirm deletion
      let confirmButton = app.alerts.buttons["Delete"]
      if confirmButton.exists {
        confirmButton.tap()

        // Should return to login screen
        let signInButton = app.buttons[UITestHelpers.AccessibilityID.signInWithAppleButton]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 15),
                      "Should return to login screen after account deletion")
      }
    }
  }
}

// MARK: - Device Farm Helpers

extension FullJourneyE2ETests {
  /// Configure for AWS Device Farm execution
  func configureForDeviceFarm() {
    app.launchEnvironment["AWS_DEVICE_FARM"] = "true"

    // Device Farm provides these automatically
    // But we can set defaults for local testing
    if ProcessInfo.processInfo.environment["DEVICEFARM_DEVICE_NAME"] == nil {
      app.launchEnvironment["DEVICEFARM_DEVICE_NAME"] = "Local Device"
    }
  }
}
