import XCTest
@testable import HushLib

class HushLibTests: XCTestCase {
    
    var dndManager: MockDNDManager!
    var screenShareDetector: MockScreenShareDetector!
    
    override func setUpWithError() throws {
        dndManager = MockDNDManager()
        screenShareDetector = MockScreenShareDetector(autoStart: true)
    }
    
    override func tearDownWithError() throws {
        dndManager = nil
        screenShareDetector = nil
    }
    
    // Test focus mode functionality
    func testFocusModeProperties() throws {
        // Test that all focus modes have correct display names
        XCTAssertEqual(FocusMode.standard.displayName, "Focus", "Standard mode should have correct display name")
        XCTAssertEqual(FocusMode.doNotDisturb.displayName, "Do Not Disturb", "DND mode should have correct display name")
        XCTAssertEqual(FocusMode.work.displayName, "Work", "Work mode should have correct display name")
        XCTAssertEqual(FocusMode.personal.displayName, "Personal", "Personal mode should have correct display name")
        XCTAssertEqual(FocusMode.sleep.displayName, "Sleep", "Sleep mode should have correct display name")
    }
    
    // Test focus options initialization
    func testFocusOptionsInit() throws {
        // Default initialization
        let defaultOptions = FocusOptions()
        XCTAssertEqual(defaultOptions.mode, .standard, "Default mode should be standard")
        XCTAssertNil(defaultOptions.duration, "Default duration should be nil")
        XCTAssertFalse(defaultOptions.enableSound, "Default sound setting should be false")
        
        // Custom initialization
        let customOptions = FocusOptions(mode: .work, duration: 60.0, enableSound: true)
        XCTAssertEqual(customOptions.mode, .work, "Mode should be set correctly")
        XCTAssertEqual(customOptions.duration, 60.0, "Duration should be set correctly")
        XCTAssertTrue(customOptions.enableSound, "Sound setting should be set correctly")
    }
    
    // Test DND manager functionality
    func testDNDManagerBasics() async throws {
        // Initially all modes should be inactive
        let initiallyActive = await dndManager.isAnyModeActive()
        XCTAssertFalse(initiallyActive, "Initially no modes should be active")
        
        for mode in FocusMode.allCases {
            let isModeActive = await dndManager.isModeActive(mode)
            XCTAssertFalse(isModeActive, "\(mode) should initially be inactive")
        }
        
        // Enable a mode
        let options = FocusOptions(mode: .work)
        try await dndManager.enableDoNotDisturb(options: options)
        
        // Verify only the expected mode is active
        let anyActive = await dndManager.isAnyModeActive()
        XCTAssertTrue(anyActive, "A mode should be active")
        
        let workActive = await dndManager.isModeActive(.work)
        XCTAssertTrue(workActive, "Work mode should be active")
        
        let standardActive = await dndManager.isModeActive(.standard)
        XCTAssertFalse(standardActive, "Standard mode should be inactive")
        
        // Disable all modes
        await dndManager.disableAllModes()
        
        // Verify all modes are inactive
        let stillActive = await dndManager.isAnyModeActive()
        XCTAssertFalse(stillActive, "No modes should be active after disableAllModes")
        
        for mode in FocusMode.allCases {
            let isModeActive = await dndManager.isModeActive(mode)
            XCTAssertFalse(isModeActive, "\(mode) should be inactive after disableAllModes")
        }
    }
    
    // Test screen share detector functionality
    func testScreenShareDetector() throws {
        // Initially not detecting screen sharing
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Initially should not detect screen sharing")
        
        // Simulate screen sharing
        screenShareDetector.simulateScreenSharing(true)
        XCTAssertTrue(screenShareDetector.isScreenSharing(), "Should detect screen sharing after simulation")
        
        // End screen sharing simulation
        screenShareDetector.simulateScreenSharing(false)
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Should not detect screen sharing after ending simulation")
    }
    
    // Test the integration of screen sharing detection and DND activation
    func testScreenSharingDNDIntegration() async throws {
        // Set up: initially no screen sharing and no DND
        screenShareDetector.simulateScreenSharing(false)
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Initially should not detect screen sharing")
        
        let initiallyActive = await dndManager.isAnyModeActive()
        XCTAssertFalse(initiallyActive, "Initially no modes should be active")
        
        // Step 1: Simulate screen sharing and enable DND
        screenShareDetector.simulateScreenSharing(true)
        if screenShareDetector.isScreenSharing() {
            let options = FocusOptions(mode: .doNotDisturb)
            try await dndManager.enableDoNotDisturb(options: options)
        }
        
        // Verify DND is active
        let dndActive = await dndManager.isModeActive(.doNotDisturb)
        XCTAssertTrue(dndActive, "DND should be active during screen sharing")
        
        // Step 2: End screen sharing and disable DND
        screenShareDetector.simulateScreenSharing(false)
        if !screenShareDetector.isScreenSharing() {
            try await dndManager.disableDoNotDisturb(mode: .doNotDisturb)
        }
        
        // Verify DND is inactive
        let dndStillActive = await dndManager.isModeActive(.doNotDisturb)
        XCTAssertFalse(dndStillActive, "DND should be inactive after screen sharing ends")
    }
} 
