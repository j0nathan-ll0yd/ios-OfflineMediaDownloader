//
//  OfflineMediaDownloaderUITests.swift
//  OfflineMediaDownloaderUITests
//
//  Created by Jonathan Lloyd on 10/21/24.
//

import XCTest

final class OfflineMediaDownloaderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGenerateScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-showPreviewCatalog"]
        app.launch()

        // Wait for the app to launch and the picker to appear
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Preview catalog picker should appear")

        let screenNames = ["Launch", "Login", "Default Files", "Files", "Account"]

        for screenName in screenNames {
            // Find the segment button within the segmented control
            let segmentButton = picker.buttons[screenName]

            if segmentButton.waitForExistence(timeout: 5) {
                segmentButton.tap()

                // Give it a moment to settle/animate
                sleep(1)

                // Take screenshot
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Screenshot-\(screenName)"
                attachment.lifetime = .keepAlways
                add(attachment)
            } else {
                XCTFail("Could not find picker button for \(screenName)")
            }
        }
    }
}
