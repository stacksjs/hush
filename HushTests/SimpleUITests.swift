import XCTest

class SimpleUITests: XCTestCase {
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
    
    // Test that the app launches successfully
    func testAppLaunch() throws {
        // Verify the app is running
        XCTAssertTrue(app.state == .runningForeground, "App should be running in the foreground")
    }
    
    // Test that a window exists
    func testWindowExists() throws {
        // Check for existence of any window
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }
    
    // Test that specific UI elements can be found via accessibility identifiers
    func testFindUIElements() throws {
        // We need to wait a moment for the UI to stabilize
        let timeout: TimeInterval = 5
        
        // Find and verify a button
        let anyButton = app.buttons.firstMatch
        XCTAssertTrue(anyButton.waitForExistence(timeout: timeout), "Should find at least one button")
        
        // Find and verify a static text
        let anyText = app.staticTexts.firstMatch
        XCTAssertTrue(anyText.waitForExistence(timeout: timeout), "Should find at least one text element")
    }
} 