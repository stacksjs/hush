import XCTest
@testable import Hush

class AppDelegateTests: XCTestCase {
    
    var appDelegate: AppDelegate!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        appDelegate = AppDelegate()
        
        // Set up minimal initialization
        appDelegate.setupIcons()
        appDelegate.setupCoreComponents()
    }
    
    override func tearDownWithError() throws {
        appDelegate = nil
        try super.tearDownWithError()
    }
    
    // Test core component initialization
    func testCoreComponentsSetup() throws {
        XCTAssertNotNil(appDelegate.screenShareDetector, "Screen share detector should be initialized")
        XCTAssertNotNil(appDelegate.dndManager, "DND manager should be initialized")
    }
    
    // Test screen sharing state change
    func testScreenSharingStateChange() throws {
        // Initially not blocking
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Initially should not be blocking")
        XCTAssertFalse(appDelegate.lastScreenSharingState, "Initially screen sharing state should be false")
        
        // Simulate screen sharing started
        appDelegate.lastScreenSharingState = true
        appDelegate.enableDoNotDisturbForScreenSharing()
        
        // Should now be blocking
        XCTAssertTrue(appDelegate.isCurrentlyBlocking, "Should be blocking when screen sharing is active")
        
        // Simulate screen sharing ended
        appDelegate.lastScreenSharingState = false
        appDelegate.disableDoNotDisturbAfterScreenSharing()
        
        // Should not be blocking anymore
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Should not be blocking when screen sharing ends")
    }
    
    // Test debug screen sharing toggle
    func testDebugScreenSharingToggle() throws {
        // Initially not in screen sharing mode
        XCTAssertFalse(appDelegate.lastScreenSharingState, "Initially screen sharing state should be false")
        
        // Create a menu item for testing
        let menuItem = NSMenuItem(title: "Test Screen Sharing", action: nil, keyEquivalent: "")
        
        // Simulate toggling on
        appDelegate.toggleTestScreenSharing(menuItem)
        
        // Should now be in screen sharing mode
        XCTAssertTrue(appDelegate.lastScreenSharingState, "Screen sharing state should be true after toggle on")
        XCTAssertTrue(appDelegate.isCurrentlyBlocking, "Should be blocking after toggling on")
        XCTAssertEqual(menuItem.title, "Test Screen Sharing (currently ON)", "Menu item title should indicate ON state")
        
        // Simulate toggling off
        appDelegate.toggleTestScreenSharing(menuItem)
        
        // Should no longer be in screen sharing mode
        XCTAssertFalse(appDelegate.lastScreenSharingState, "Screen sharing state should be false after toggle off")
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Should not be blocking after toggling off")
        XCTAssertEqual(menuItem.title, "Test Screen Sharing (currently OFF)", "Menu item title should indicate OFF state")
    }
    
    // Test status menu item updates
    func testStatusMenuItemUpdates() throws {
        // Create a status menu for testing
        appDelegate.statusMenu = NSMenu()
        appDelegate.statusMenu.addItem(NSMenuItem(title: "Status: Not currently blocking", action: nil, keyEquivalent: ""))
        
        // Test updating to blocking state
        appDelegate.updateStatusMenuItem(blocking: true)
        XCTAssertEqual(appDelegate.statusMenu.item(at: 0)?.title, "Status: Blocking notifications", "Status should indicate blocking")
        
        // Test updating to non-blocking state
        appDelegate.updateStatusMenuItem(blocking: false)
        XCTAssertEqual(appDelegate.statusMenu.item(at: 0)?.title, "Status: Not currently blocking", "Status should indicate not blocking")
    }
    
    // Test preferences loading and saving
    func testPreferencesLoadSave() throws {
        // Modify a preference
        appDelegate.preferences.showNotifications = false
        
        // Save preferences
        appDelegate.savePreferences()
        
        // Load preferences in a new instance
        let newAppDelegate = AppDelegate()
        newAppDelegate.loadPreferences()
        
        // Check if the preference was saved and loaded correctly
        XCTAssertFalse(newAppDelegate.preferences.showNotifications, "Preference should be saved and loaded correctly")
    }
    
    // Test statistics tracking
    func testStatisticsTracking() throws {
        // Get initial activation count
        let initialActivations = appDelegate.statistics.screenSharingActivations
        
        // Simulate screen sharing started
        appDelegate.enableDoNotDisturbForScreenSharing()
        
        // Activation count should increase
        XCTAssertEqual(appDelegate.statistics.screenSharingActivations, initialActivations + 1, "Activation count should increase")
        XCTAssertNotNil(appDelegate.statistics.lastActivated, "Last activated timestamp should be set")
        
        // Simulate screen sharing ended
        appDelegate.disableDoNotDisturbAfterScreenSharing()
        
        // Should record deactivation time
        XCTAssertNotNil(appDelegate.statistics.lastDeactivated, "Last deactivated timestamp should be set")
    }
} 
