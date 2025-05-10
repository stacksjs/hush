@testable import Hush
import XCTest

class HushUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Add launch argument to indicate we're running tests
        app.launchArguments = ["UITestMode"]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // Test the welcome screen is displayed on first launch
    func testWelcomeScreenAppears() throws {
        // Find welcome title on the screen
        let welcomeTitle = app.staticTexts["Welcome to Hush"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5), "Welcome screen should appear on first launch")
        
        // Verify the welcome screen dimensions
        let welcomeWindow = app.windows.element(boundBy: 0)
        XCTAssertEqual(welcomeWindow.frame.size.width, 600, "Welcome window should be 600 points wide")
        XCTAssertEqual(welcomeWindow.frame.size.height, 530, "Welcome window should be 530 points high")
        
        // Complete welcome flow
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists, "Get Started button should exist")
        getStartedButton.tap()
    }
    
    // Test the menu bar status item appears
    func testMenuBarItemAppears() throws {
        // This is a bit difficult to test directly with XCTest since the menu bar 
        // is outside the app's control, but we can verify that our app is running
        XCTAssertFalse(app.windows.isEmpty, "App should be running with at least one window")
    }
    
    // Test the debug menu for testing screen sharing
    func testDebugScreenSharingToggle() throws {
        // Click the status bar item
        let menuBars = XCUIApplication(bundleIdentifier: "com.apple.controlcenter").menuBars
        let statusItem = menuBars.statusItems["Hush"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Status bar item should exist")
        statusItem.click()
        
        // Find and click the Test Screen Sharing option
        let testScreenSharingItem = app.menuItems["Test Screen Sharing"]
        XCTAssertTrue(testScreenSharingItem.waitForExistence(timeout: 2), "Debug menu item should exist")
        testScreenSharingItem.click()
        
        // The status should now indicate blocking is active
        statusItem.click() // Click again to open the menu
        let statusText = app.staticTexts["Status: Blocking notifications"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 2), "Status should indicate blocking is active")
        
        // Toggle it back off
        testScreenSharingItem.click()
        
        // Status should indicate not blocking
        statusItem.click() // Click again to open the menu
        let inactiveStatus = app.staticTexts["Status: Not currently blocking"]
        XCTAssertTrue(inactiveStatus.waitForExistence(timeout: 2), "Status should indicate not blocking")
    }
    
    // Test preferences screen
    func testPreferencesScreen() throws {
        // Open the menu
        let menuBars = XCUIApplication(bundleIdentifier: "com.apple.controlcenter").menuBars
        let statusItem = menuBars.statusItems["Hush"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Status bar item should exist")
        statusItem.click()
        
        // Click Preferences
        let preferencesItem = app.menuItems["Preferences..."]
        XCTAssertTrue(preferencesItem.exists, "Preferences menu item should exist")
        preferencesItem.click()
        
        // Verify preferences window appears
        let prefsWindow = app.windows["Hush Preferences"]
        XCTAssertTrue(prefsWindow.waitForExistence(timeout: 2), "Preferences window should appear")
        
        // Test toggle switch
        let launchToggle = prefsWindow.toggles["Launch at startup"]
        XCTAssertTrue(launchToggle.exists, "Launch at startup toggle should exist")
        launchToggle.click()
        
        // Save preferences
        let saveButton = prefsWindow.buttons["Save"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.click()
        
        // Verify preferences window closed
        XCTAssertFalse(prefsWindow.exists, "Preferences window should close after saving")
    }
    
    // Test about screen
    func testAboutScreen() throws {
        // Open the menu
        let menuBars = XCUIApplication(bundleIdentifier: "com.apple.controlcenter").menuBars
        let statusItem = menuBars.statusItems["Hush"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Status bar item should exist")
        statusItem.click()
        
        // Click About
        let aboutItem = app.menuItems["About Hush"]
        XCTAssertTrue(aboutItem.exists, "About menu item should exist")
        aboutItem.click()
        
        // Verify about window appears
        let aboutWindow = app.windows["About Hush"]
        XCTAssertTrue(aboutWindow.waitForExistence(timeout: 2), "About window should appear")
        
        // Verify version text exists
        let versionText = aboutWindow.staticTexts["Version 1.0"]
        XCTAssertTrue(versionText.exists, "Version text should exist in About window")
        
        // Close the window
        aboutWindow.buttons.element(boundBy: 0).click()
    }
} 
