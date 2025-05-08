import XCTest
import Synchronization // New in Swift 6

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
struct MockFocusOptions: Sendable { // Added Sendable for concurrency safety
    var mode: MockFocusMode = .standard
    var duration: TimeInterval? = nil
    
    init(mode: MockFocusMode = .standard, duration: TimeInterval? = nil) {
        self.mode = mode
        self.duration = duration
    }
}

/// Mock class for Do Not Disturb management
@DebugDescription // Using Swift 6's new debugging macro
actor MockDNDManager { // Changed to actor for safer concurrency
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
        Task { @MainActor in
            NotificationCenter.default.post(
                name: Self.focusModeChangedNotification,
                object: self,
                userInfo: ["mode": options.mode.rawValue, "active": true]
            )
        }
    }
    
    func disableDoNotDisturb(mode: MockFocusMode) {
        // Set the specified mode as inactive
        activeModes[mode] = false
        
        // Post a notification
        Task { @MainActor in
            NotificationCenter.default.post(
                name: Self.focusModeChangedNotification,
                object: self,
                userInfo: ["mode": mode.rawValue, "active": false]
            )
        }
    }
    
    func isAnyModeActive() -> Bool {
        return activeModes.values.contains(true)
    }
    
    func isModeActive(_ mode: MockFocusMode) -> Bool {
        return activeModes[mode] ?? false
    }
    
    var debugDescription: String {
        "DNDManager: Active modes: \(activeModes.filter { $0.value }.keys.map { $0.rawValue }.joined(separator: ", "))"
    }
}

/// Mock class for screen sharing detection
class MockScreenShareDetector {
    private let isDetectingAtomic = Atomic<Bool>(false) // Using Swift 6 Atomic from Synchronization
    private let screenSharingState = Atomic<Bool>(false)
    
    init(autoStart: Bool = false) {
        if autoStart {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        isDetectingAtomic.store(true)
    }
    
    func stopMonitoring() {
        isDetectingAtomic.store(false)
    }
    
    func isScreenSharing() -> Bool {
        return screenSharingState.load()
    }
    
    func isDetecting() -> Bool {
        return isDetectingAtomic.load()
    }
    
    // For testing purposes
    func simulateScreenSharing(_ isSharing: Bool) throws(ScreenShareError) {
        if !isDetectingAtomic.load() {
            throw ScreenShareError.notMonitoring
        }
        screenSharingState.store(isSharing)
    }
}

// Custom error type for screen sharing operations (Swift 6 typed throws)
enum ScreenShareError: Error {
    case notMonitoring
    case detectionFailed
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
    
    func testEnableDisableDoNotDisturb() async throws {
        // Initially no modes should be active
        XCTAssertFalse(await dndManager.isAnyModeActive(), "No modes should be active initially")
        
        // Enable Do Not Disturb
        let options = MockFocusOptions(mode: .standard)
        await dndManager.enableDoNotDisturb(options: options)
        
        // Verify it's active
        XCTAssertTrue(await dndManager.isAnyModeActive(), "A mode should be active")
        XCTAssertTrue(await dndManager.isModeActive(.standard), "Standard mode should be active")
        
        // Disable it
        await dndManager.disableDoNotDisturb(mode: .standard)
        
        // Verify it's inactive
        XCTAssertFalse(await dndManager.isAnyModeActive(), "No modes should be active after disabling")
        XCTAssertFalse(await dndManager.isModeActive(.standard), "Standard mode should be inactive")
    }
    
    func testScreenSharingDetection() async throws {
        // Initially not detecting screen sharing
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Should not detect screen sharing initially")
        
        // Simulate screen sharing
        try screenShareDetector.simulateScreenSharing(true)
        XCTAssertTrue(screenShareDetector.isScreenSharing(), "Should detect screen sharing after simulation")
        
        // Enable DND when screen sharing is detected
        if screenShareDetector.isScreenSharing() {
            let options = MockFocusOptions(mode: .doNotDisturb)
            await dndManager.enableDoNotDisturb(options: options)
        }
        
        // Verify DND is active
        XCTAssertTrue(await dndManager.isModeActive(.doNotDisturb), "DND should be active during screen sharing")
        
        // End screen sharing
        try screenShareDetector.simulateScreenSharing(false)
        XCTAssertFalse(screenShareDetector.isScreenSharing(), "Should not detect screen sharing after ending simulation")
        
        // Disable DND when screen sharing ends
        if !screenShareDetector.isScreenSharing() {
            await dndManager.disableDoNotDisturb(mode: .doNotDisturb)
        }
        
        // Verify DND is inactive
        XCTAssertFalse(await dndManager.isModeActive(.doNotDisturb), "DND should be inactive after screen sharing ends")
    }
    
    // Test Swift 6's typed throws feature
    func testScreenSharingSimulationErrors() throws(ScreenShareError) {
        // Create a detector that's not monitoring
        let detector = MockScreenShareDetector(autoStart: false)
        XCTAssertFalse(detector.isDetecting(), "Detector should not be monitoring")
        
        // This should throw a ScreenShareError.notMonitoring
        try detector.simulateScreenSharing(true)
    }
    
    // Test Swift 6's typed throws with do-catch
    func testErrorHandling() {
        // Create a detector that's not monitoring
        let detector = MockScreenShareDetector(autoStart: false)
        
        do {
            try detector.simulateScreenSharing(true)
            XCTFail("Should have thrown an error")
        } catch ScreenShareError.notMonitoring {
            // This is expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
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
        await dndManager.enableDoNotDisturb(options: options)
        
        // Wait for notification
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify notification was received
        XCTAssertTrue(notificationReceived, "Should receive notification when DND is enabled")
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    // Test Swift 6's concurrency improvements
    func testConcurrentAccess() async throws {
        // Test concurrent access to the MockDNDManager actor
        async let task1 = dndManager.enableDoNotDisturb(options: MockFocusOptions(mode: .standard))
        async let task2 = dndManager.enableDoNotDisturb(options: MockFocusOptions(mode: .doNotDisturb))
        
        // Wait for both tasks to complete
        await (task1, task2)
        
        // Verify both modes are active
        XCTAssertTrue(await dndManager.isModeActive(.standard), "Standard mode should be active")
        XCTAssertTrue(await dndManager.isModeActive(.doNotDisturb), "DND mode should be active")
    }
} 