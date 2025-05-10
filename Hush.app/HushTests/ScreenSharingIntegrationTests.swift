import XCTest
@testable import Hush

class ScreenSharingIntegrationTests: XCTestCase {
    
    var appDelegate: AppDelegate!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        appDelegate = AppDelegate()
        appDelegate.setupIcons()
        appDelegate.setupCoreComponents()
        appDelegate.setupMonitoring()
    }
    
    override func tearDownWithError() throws {
        // Make sure any screen recording is stopped
        _ = ScreenShareSimulator.stopScreenRecording()
        appDelegate = nil
        try super.tearDownWithError()
    }
    
    // This test can be marked as skipped by default since it launches actual applications
    // and may require manual interaction
    func testRealScreenSharingDetection() throws {
        throw XCTSkip("This test requires permission grants and may launch external applications")
        
        // Initially not blocking
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Initially should not be blocking")
        
        // Start a screen recording
        let screenSharingStarted = ScreenShareSimulator.startScreenRecording()
        XCTAssertTrue(screenSharingStarted, "Screen recording should start")
        
        // Wait for the app to detect screen sharing
        let screenSharingDetectedExpectation = expectation(description: "Screen sharing detected")
        
        // Poll for the app to detect screen sharing
        var detectionAttempts = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            detectionAttempts += 1
            
            // Check if the app detects screen sharing
            self.appDelegate.checkScreenShareStatus()
            
            if self.appDelegate.isCurrentlyBlocking {
                screenSharingDetectedExpectation.fulfill()
                timer.invalidate()
            }
            
            // Time out after 10 attempts
            if detectionAttempts >= 10 {
                timer.invalidate()
            }
        }
        
        // Wait for the expectation to be fulfilled or timeout
        wait(for: [screenSharingDetectedExpectation], timeout: 15.0)
        
        // Stop the screen recording
        let screenSharingStopped = ScreenShareSimulator.stopScreenRecording()
        XCTAssertTrue(screenSharingStopped, "Screen recording should stop")
        
        // Wait for the app to detect screen sharing ended
        let screenSharingEndedExpectation = expectation(description: "Screen sharing ended")
        
        // Poll for the app to detect screen sharing ended
        detectionAttempts = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            detectionAttempts += 1
            
            // Check if the app detects screen sharing ended
            self.appDelegate.checkScreenShareStatus()
            
            if !self.appDelegate.isCurrentlyBlocking {
                screenSharingEndedExpectation.fulfill()
                timer.invalidate()
            }
            
            // Time out after 10 attempts
            if detectionAttempts >= 10 {
                timer.invalidate()
            }
        }
        
        // Wait for the expectation to be fulfilled or timeout
        wait(for: [screenSharingEndedExpectation], timeout: 15.0)
        
        // Verify we're no longer blocking
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Should not be blocking after screen sharing ends")
    }
    
    // Test detection with the debug menu option
    func testDebugScreenSharingDetection() throws {
        // Initially not blocking
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Initially should not be blocking")
        
        // Create a mock menu item
        let menuItem = NSMenuItem(title: "Test Screen Sharing", action: nil, keyEquivalent: "")
        
        // Toggle on screen sharing simulation
        appDelegate.toggleTestScreenSharing(menuItem)
        
        // Verify we're blocking and the menu item is updated
        XCTAssertTrue(appDelegate.isCurrentlyBlocking, "Should be blocking after toggling debug screen sharing")
        XCTAssertEqual(menuItem.title, "Test Screen Sharing (currently ON)", "Menu item should indicate ON state")
        
        // Toggle off screen sharing simulation
        appDelegate.toggleTestScreenSharing(menuItem)
        
        // Verify we're no longer blocking and the menu item is updated
        XCTAssertFalse(appDelegate.isCurrentlyBlocking, "Should not be blocking after toggling off debug screen sharing")
        XCTAssertEqual(menuItem.title, "Test Screen Sharing (currently OFF)", "Menu item should indicate OFF state")
    }
    
    // Test that the app correctly updates statistics when screen sharing is detected
    func testStatisticsUpdatedDuringScreenSharing() throws {
        // Store initial statistics values
        let initialActivations = appDelegate.statistics.screenSharingActivations
        let initialSessionCount = appDelegate.statistics.sessionCount
        
        // Simulate screen sharing with debug toggle
        let menuItem = NSMenuItem(title: "Test Screen Sharing", action: nil, keyEquivalent: "")
        appDelegate.toggleTestScreenSharing(menuItem)
        
        // Verify statistics updated for activation
        XCTAssertEqual(appDelegate.statistics.screenSharingActivations, initialActivations + 1, "Activation count should increase")
        XCTAssertNotNil(appDelegate.statistics.lastActivated, "Last activated timestamp should be set")
        
        // Simulate a short delay
        Thread.sleep(forTimeInterval: 1.0)
        
        // End screen sharing
        appDelegate.toggleTestScreenSharing(menuItem)
        
        // Verify statistics updated for deactivation
        XCTAssertNotNil(appDelegate.statistics.lastDeactivated, "Last deactivated timestamp should be set")
        XCTAssertEqual(appDelegate.statistics.sessionCount, initialSessionCount + 1, "Session count should increase")
        XCTAssertGreaterThan(appDelegate.statistics.totalActiveTime, 0, "Total active time should be recorded")
    }
} 
