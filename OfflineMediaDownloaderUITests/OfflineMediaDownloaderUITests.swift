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

        // Wait for the app to fully launch
        sleep(2)

        // Wait for the picker to appear using accessibility identifier
        let picker = app.segmentedControls["ScreenPicker"]
        let pickerExists = picker.waitForExistence(timeout: 15)
        
        // Fallback to first segmented control if accessibility identifier not found
        let actualPicker: XCUIElement
        if pickerExists {
            actualPicker = picker
        } else {
            actualPicker = app.segmentedControls.firstMatch
            XCTAssertTrue(actualPicker.waitForExistence(timeout: 10), "Preview catalog picker should appear")
        }

        // Screen names must match ScreenType.rawValue in RedesignPreviewCatalog.swift
        let screenNames = ["Launch", "Login", "Default", "Files", "Detail", "Account"]

        for screenName in screenNames {
            // Find the segment button within the segmented control
            let segmentButton = actualPicker.buttons[screenName]

            // Wait longer for the button to appear (CI can be slow)
            if segmentButton.waitForExistence(timeout: 10) {
                segmentButton.tap()

                // Give it more time to settle/animate in CI
                sleep(2)

                // Take screenshot
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Screenshot-\(screenName)"
                attachment.lifetime = .keepAlways
                add(attachment)
            } else {
                // Log available buttons for debugging
                let availableButtons = actualPicker.buttons.allElementsBoundByIndex.map { $0.label }
                XCTFail("Could not find picker button for '\(screenName)'. Available buttons: \(availableButtons)")
            }
        }
    }
}
