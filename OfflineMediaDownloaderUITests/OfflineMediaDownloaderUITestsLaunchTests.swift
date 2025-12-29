//
//  OfflineMediaDownloaderUITestsLaunchTests.swift
//  OfflineMediaDownloaderUITests
//
//  Created by Jonathan Lloyd on 10/21/24.
//

import XCTest

final class OfflineMediaDownloaderUITestsLaunchTests: XCTestCase {

    // Disabled multi-configuration runs to avoid flaky tests with animated launch screen
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for launch animation to complete before taking screenshot
        // The animated launch screen needs time to settle
        sleep(2)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
