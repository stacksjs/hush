import XCTest
@testable import Hush

class DNDManagerTests: XCTestCase {
    
    var dndManager: DNDManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        dndManager = DNDManager()
    }
    
    override func tearDownWithError() throws {
        dndManager = nil
        try super.tearDownWithError()
    }
    
    // Test the initialization of the DNDManager
    func testInitialization() throws {
        XCTAssertNotNil(dndManager, "DNDManager should be initialized properly")
    }
    
    // Test enabling Do Not Disturb
    func testEnableDoNotDisturb() throws {
        // Setup notification observation
        let expectation = self.expectation(description: "DND mode changed notification")
        var notificationReceived = false
        
        let observer = NotificationCenter.default.addObserver(
            forName: DNDManager.focusModeChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let active = userInfo["active"] as? Bool,
               active == true {
                notificationReceived = true
                expectation.fulfill()
            }
        }
        
        // Create options
        var options = FocusOptions()
        options.mode = .standard
        options.duration = nil  // indefinite
        
        // Enable DND
        dndManager.enableDoNotDisturb(options: options)
        
        // Wait for notification
        waitForExpectations(timeout: 2, handler: nil)
        
        // Validate
        XCTAssertTrue(notificationReceived, "Should receive notification when DND is enabled")
        XCTAssertTrue(dndManager.isAnyModeActive(), "DND should be active")
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    // Test disabling Do Not Disturb
    func testDisableDoNotDisturb() throws {
        // First enable DND
        var options = FocusOptions()
        options.mode = .standard
        dndManager.enableDoNotDisturb(options: options)
        
        // Setup notification observation for disable
        let expectation = self.expectation(description: "DND mode disabled notification")
        var notificationReceived = false
        
        let observer = NotificationCenter.default.addObserver(
            forName: DNDManager.focusModeChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let active = userInfo["active"] as? Bool,
               active == false {
                notificationReceived = true
                expectation.fulfill()
            }
        }
        
        // Disable DND
        dndManager.disableDoNotDisturb(mode: .standard)
        
        // Wait for notification
        waitForExpectations(timeout: 2, handler: nil)
        
        // Validate
        XCTAssertTrue(notificationReceived, "Should receive notification when DND is disabled")
        XCTAssertFalse(dndManager.isAnyModeActive(), "No DND mode should be active")
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    // Test disabling all modes
    func testDisableAllModes() throws {
        // Enable multiple modes
        var optionsStandard = FocusOptions()
        optionsStandard.mode = .standard
        dndManager.enableDoNotDisturb(options: optionsStandard)
        
        var optionsWork = FocusOptions()
        optionsWork.mode = .work
        dndManager.enableDoNotDisturb(options: optionsWork)
        
        // Disable all modes
        dndManager.disableAllModes()
        
        // Validate
        XCTAssertFalse(dndManager.isAnyModeActive(), "No DND mode should be active after disableAllModes")
        XCTAssertFalse(dndManager.isModeActive(.standard), "Standard mode should be inactive")
        XCTAssertFalse(dndManager.isModeActive(.work), "Work mode should be inactive")
    }
    
    // Test checking active modes
    func testIsModeActive() throws {
        // Initially no modes should be active
        XCTAssertFalse(dndManager.isModeActive(.standard), "Standard mode should initially be inactive")
        XCTAssertFalse(dndManager.isModeActive(.work), "Work mode should initially be inactive")
        
        // Enable standard mode
        var optionsStandard = FocusOptions()
        optionsStandard.mode = .standard
        dndManager.enableDoNotDisturb(options: optionsStandard)
        
        // Check active state
        XCTAssertTrue(dndManager.isModeActive(.standard), "Standard mode should be active")
        XCTAssertFalse(dndManager.isModeActive(.work), "Work mode should still be inactive")
        
        // Disable standard mode
        dndManager.disableDoNotDisturb(mode: .standard)
        
        // Check inactive state
        XCTAssertFalse(dndManager.isModeActive(.standard), "Standard mode should be inactive after disabling")
    }
} 