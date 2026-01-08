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
        
        let screenNames = ["Launch", "Login", "Default Files", "Files", "Account"]
        
        for screenName in screenNames {
            // Find the picker button for this screen
            let pickerButton = app.buttons[screenName]
            
            // If it's not selected or not visible, we might need to tap it.
            if pickerButton.exists {
                pickerButton.tap()
                
                // Give it a moment to settle/animate
                sleep(1)
                
                // Take screenshot
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Screenshot-\(screenName)"
                attachment.lifetime = .keepAlways
                add(attachment)
            } else {
                // If the screen name button doesn't exist, we fail.
                // Note: We might need to handle the case where the picker isn't immediately visible, 
                // but for a preview catalog it should be.
                XCTFail("Could not find picker button for \(screenName)")
            }
        }
    }
}
