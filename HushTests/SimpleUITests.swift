import XCTest
import Testing
import Synchronization

@MainActor // Ensures UI-related code runs on main thread for Swift 6 safety
final class SimpleUITests: XCTestCase {
    
    // Using atomics for thread-safe test state
    private let hasSetUp = Atomic<Bool>(false)
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        hasSetUp.store(true)
    }
    
    override func tearDownWithError() throws {
        // Teardown code
    }
    
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testBasicUIInteraction() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Simple UI interaction test
        let menuBarItem = app.menuBarItems["Hush"]
        XCTAssertTrue(menuBarItem.exists, "Menu bar item should exist")
        
        if menuBarItem.exists {
            menuBarItem.click()
            // Wait for menu to appear
            let aboutMenuItem = app.menuItems["About Hush"]
            XCTAssertTrue(aboutMenuItem.waitForExistence(timeout: 2), "About menu item should appear")
        }
    }
    
    // Test using async/await for better readability and concurrency safety
    func testPreferencesUI() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Access preferences
        let menuBarItem = app.menuBarItems["Hush"]
        await menuBarItem.click()
        
        let preferencesMenuItem = app.menuItems["Preferences"]
        if await preferencesMenuItem.waitForExistence(timeout: 2) {
            await preferencesMenuItem.click()
            
            // Verify preferences window appears
            let preferencesWindow = app.windows["Preferences"]
            XCTAssertTrue(await preferencesWindow.waitForExistence(timeout: 2), "Preferences window should appear")
        }
    }
}

// Swift Testing framework version of UI tests
@Suite("Hush UI Tests")
@MainActor
struct HushUITests {
    
    @Test("App launches successfully")
    func testAppLaunch() {
        let app = XCUIApplication()
        app.launch()
        
        // Verify app is running
        #expect(app.wait(for: .runningForeground, timeout: 5))
    }
    
    @Test("Menu bar item exists")
    func testMenuBarItem() {
        let app = XCUIApplication()
        app.launch()
        
        let menuBarItem = app.menuBarItems["Hush"]
        #expect(menuBarItem.exists)
    }
    
    @Test("Can toggle settings")
    func testToggleSettings() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to preferences
        let menuBarItem = app.menuBarItems["Hush"]
        menuBarItem.click()
        
        let preferencesMenuItem = app.menuItems["Preferences"]
        if preferencesMenuItem.waitForExistence(timeout: 2) {
            preferencesMenuItem.click()
            
            // Find a toggle in preferences
            let toggles = app.switches.allElementsBoundByIndex
            if !toggles.isEmpty {
                let firstToggle = toggles[0]
                
                // Get initial state
                let initialValue = firstToggle.value as? String
                
                // Toggle it
                firstToggle.click()
                
                // Verify it changed
                let newValue = firstToggle.value as? String
                #expect(initialValue != newValue)
            }
        }
    }
} 