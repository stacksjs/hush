import XCTest

// MARK: - Mock Models

/// Mock implementation of a focus mode
enum MockFocusMode: String, CaseIterable {
    case standard = "Focus"
    case doNotDisturb = "Do Not Disturb"
    
    var displayName: String {
        return self.rawValue
    }
}

/// Mock implementation of focus options
struct MockFocusOptions {
    var mode: MockFocusMode = .standard
    var duration: TimeInterval? = nil
    
    init(mode: MockFocusMode = .standard, duration: TimeInterval? = nil) {
        self.mode = mode
        self.duration = duration
    }
}

/// Mock class for Do Not Disturb management
class MockDNDManager {
    private var activeModes: [MockFocusMode: Bool] = [:]
    static let focusModeChangedNotification = Notification.Name("MockFocusModeChangedNotification")
    
    init() {
        // Initialize all modes as inactive
        for mode in MockFocusMode.allCases {
            activeModes[mode] = false
        }
    }
    
    func enableDoNotDisturb(options: MockFocusOptions) {
        // Set the specified mode as active
        activeModes[options.mode] = true
        
        // Post a notification
        NotificationCenter.default.post(
            name: Self.focusModeChangedNotification,
            object: self,
            userInfo: ["mode": options.mode.rawValue, "active": true]
        )
    }
    
    func disableDoNotDisturb(mode: MockFocusMode) {
        // Set the specified mode as inactive
        activeModes[mode] = false
        
        // Post a notification
        NotificationCenter.default.post(
            name: Self.focusModeChangedNotification,
            object: self,
            userInfo: ["mode": mode.rawValue, "active": false]
        )
    }
    
    func isAnyModeActive() -> Bool {
        return activeModes.values.contains(true)
    }
    
    func isModeActive(_ mode: MockFocusMode) -> Bool {
        return activeModes[mode] ?? false
    }
}

/// Mock class for screen sharing detection
class MockScreenShareDetector {
    private var isDetecting = false
    private var simulatedScreenSharing = false
    
    init(autoStart: Bool = false) {
        if autoStart {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        isDetecting = true
    }
    
    func stopMonitoring() {
        isDetecting = false
    }
    
    func isScreenSharing() -> Bool {
        return simulatedScreenSharing
    }
    
    // For testing purposes
    func simulateScreenSharing(_ isSharing: Bool) {
        simulatedScreenSharing = isSharing
    }
}

// MARK: - Tests

class MockDNDTests: XCTestCase {
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
    
    func testEnableDisableDoNotDisturb() throws {
        // Initially no modes should be active
        XCTAssertFalse(dndManager.isAnyModeActive(), "No modes should be active initially")
        
        // Enable Do Not Disturb
        let options = MockFocusOptions(mode: .standard)
        dndManager.enableDoNotDisturb(options: options)
        
        // Verify it's active
        XCTAssertTrue(dndManager.isAnyModeActive(), "A mode should be active")
        XCTAssertTrue(dndManager.isModeActive(.standard), "Standard mode should be active")
        
        // Disable it
        dndManager.disableDoNotDisturb(mode: .standard)
        
        // Verify it's inactive
        XCTAssertFalse(dndManager.isAnyModeActive(), "No modes should be active after disabling")
        XCTAssertFalse(dndManager.isModeActive(.standard), "Standard mode should be inactive")
    }
    
    func testScreenSharingDetection() throws {
        // Initially not detecting screen sharing
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Should not detect screen sharing initially")
        
        // Simulate screen sharing
        screenShareDetector.simulateScreenSharing(true)
        XCTAssertTrue(screenShareDetector.isScreenSharing(), "Should detect screen sharing after simulation")
        
        // Enable DND when screen sharing is detected
        if screenShareDetector.isScreenSharing() {
            let options = MockFocusOptions(mode: .doNotDisturb)
            dndManager.enableDoNotDisturb(options: options)
        }
        
        // Verify DND is active
        XCTAssertTrue(dndManager.isModeActive(.doNotDisturb), "DND should be active during screen sharing")
        
        // End screen sharing
        screenShareDetector.simulateScreenSharing(false)
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Should not detect screen sharing after ending simulation")
        
        // Disable DND when screen sharing ends
        if !screenShareDetector.isScreenSharing() {
            dndManager.disableDoNotDisturb(mode: .doNotDisturb)
        }
        
        // Verify DND is inactive
        XCTAssertFalse(dndManager.isModeActive(.doNotDisturb), "DND should be inactive after screen sharing ends")
    }
    
    func testAsyncNotificationObservation() async throws {
        // Set up notification observation
        let expectation = expectation(description: "DND mode changed notification")
        var notificationReceived = false
        
        let observer = NotificationCenter.default.addObserver(
            forName: MockDNDManager.focusModeChangedNotification,
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
        
        // Enable DND
        let options = MockFocusOptions(mode: .standard)
        dndManager.enableDoNotDisturb(options: options)
        
        // Wait for notification
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify notification was received
        XCTAssertTrue(notificationReceived, "Should receive notification when DND is enabled")
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
} 