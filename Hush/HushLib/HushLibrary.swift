import Foundation

// MARK: - Core Models

/// Focus modes available in the app
public enum FocusMode: String, CaseIterable, Codable {
    case standard = "Focus"
    case doNotDisturb = "Do Not Disturb" 
    case work = "Work"
    case personal = "Personal"
    case sleep = "Sleep"
    
    public var displayName: String {
        return self.rawValue
    }
}

/// Options for Focus management
public struct FocusOptions {
    public var mode: FocusMode = .standard
    public var duration: TimeInterval? = nil  // nil means indefinite, otherwise in seconds
    public var enableSound: Bool = false
    
    public init(mode: FocusMode = .standard, duration: TimeInterval? = nil, enableSound: Bool = false) {
        self.mode = mode
        self.duration = duration
        self.enableSound = enableSound
    }
}

/// Core functionality for detecting screen sharing
public protocol ScreenShareDetectorProtocol {
    func isScreenSharing() -> Bool
    func startMonitoring()
    func stopMonitoring()
}

/// Core functionality for Do Not Disturb management
public protocol DNDManagerProtocol {
    func enableDoNotDisturb(options: FocusOptions)
    func disableDoNotDisturb(mode: FocusMode)
    func disableAllModes()
    func isAnyModeActive() -> Bool
    func isModeActive(_ mode: FocusMode) -> Bool
}

// MARK: - Mock Implementation for Testing

/// A test implementation of screen share detector
public class MockScreenShareDetector: ScreenShareDetectorProtocol {
    private var isDetecting = false
    private var simulatedScreenSharing = false
    
    public init(autoStart: Bool = false) {
        if autoStart {
            startMonitoring()
        }
    }
    
    public func startMonitoring() {
        isDetecting = true
    }
    
    public func stopMonitoring() {
        isDetecting = false
    }
    
    public func isScreenSharing() -> Bool {
        return simulatedScreenSharing
    }
    
    public func simulateScreenSharing(_ isSharing: Bool) {
        simulatedScreenSharing = isSharing
    }
}

/// A test implementation of DND manager
public class MockDNDManager: DNDManagerProtocol {
    private var activeModes: [FocusMode: Bool] = [:]
    public static let focusModeChangedNotification = Notification.Name("MockFocusModeChangedNotification")
    
    public init() {
        for mode in FocusMode.allCases {
            activeModes[mode] = false
        }
    }
    
    public func enableDoNotDisturb(options: FocusOptions) {
        activeModes[options.mode] = true
        
        NotificationCenter.default.post(
            name: Self.focusModeChangedNotification,
            object: self,
            userInfo: ["mode": options.mode.rawValue, "active": true]
        )
    }
    
    public func disableDoNotDisturb(mode: FocusMode) {
        activeModes[mode] = false
        
        NotificationCenter.default.post(
            name: Self.focusModeChangedNotification,
            object: self,
            userInfo: ["mode": mode.rawValue, "active": false]
        )
    }
    
    public func disableAllModes() {
        for mode in FocusMode.allCases {
            activeModes[mode] = false
        }
    }
    
    public func isAnyModeActive() -> Bool {
        return activeModes.values.contains(true)
    }
    
    public func isModeActive(_ mode: FocusMode) -> Bool {
        return activeModes[mode] ?? false
    }
} 