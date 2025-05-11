import Foundation

// MARK: - Core Models

/// Focus modes available in the app
@available(macOS 14.0, *)
public enum FocusMode: String, CaseIterable, Codable, Sendable {
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
@available(macOS 14.0, *)
public struct FocusOptions: Sendable {
    public var mode: FocusMode = .standard
    public var duration: TimeInterval? = nil  // nil means indefinite, otherwise in seconds
    public var enableSound: Bool = false
    
    public init(mode: FocusMode = .standard, duration: TimeInterval? = nil, enableSound: Bool = false) {
        self.mode = mode
        self.duration = duration
        self.enableSound = enableSound
    }
}

/// Errors that can occur in DNDManager
@available(macOS 14.0, *)
public enum DNDError: Error, Sendable {
    case scriptExecutionFailed(String)
    case focusModeNotAvailable(FocusMode)
    case systemServiceUnavailable
    case permissionDenied
    case systemError(String)
}

/// Core functionality for detecting screen sharing
@available(macOS 14.0, *)
public protocol ScreenShareDetectorProtocol {
    func isScreenSharing() -> Bool
    func startMonitoring() async
    func stopMonitoring() async
}

/// Core functionality for Do Not Disturb management
/// Swift 6 version with actor isolation and async/await
@available(macOS 14.0, *)
public protocol DNDManagerProtocol: Actor {
    /// Enable Do Not Disturb mode with options
    #if swift(>=6.0) && swift(<6.1)
    func enableDoNotDisturb(options: FocusOptions) async throws -> Void
    #else
    func enableDoNotDisturb(options: FocusOptions) async throws(DNDError)
    #endif
    
    /// Disable a specific Do Not Disturb mode
    #if swift(>=6.0) && swift(<6.1)
    func disableDoNotDisturb(mode: FocusMode) async throws -> Void
    #else
    func disableDoNotDisturb(mode: FocusMode) async throws(DNDError)
    #endif
    
    /// Disable all active Focus modes
    func disableAllModes() async
    
    /// Check if any Focus mode is active
    func isAnyModeActive() async -> Bool
    
    /// Check if a specific mode is active
    func isModeActive(_ mode: FocusMode) async -> Bool
}

// MARK: - Mock Implementation for Testing

/// A thread-safe implementation of screen share detector for Swift 6
@available(macOS 14.0, *)
public actor MockScreenShareDetector: ScreenShareDetectorProtocol, CustomDebugStringConvertible {
    // Properties marked as nonisolated can be accessed from any context
    nonisolated private let isDetecting = Synchronization.Atomic<Bool>(false)
    nonisolated private let simulatedScreenSharing = Synchronization.Atomic<Bool>(false)
    
    public init(autoStart: Bool = false) {
        if autoStart {
            Task { await startMonitoring() }
        }
    }
    
    public func startMonitoring() async {
        isDetecting.store(true, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    public func stopMonitoring() async {
        isDetecting.store(false, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    // Using nonisolated keyword makes this function callable from any context
    public nonisolated func isScreenSharing() -> Bool {
        // Accessing simulatedScreenSharing is safe because Atomic provides its own thread safety
        return simulatedScreenSharing.load(ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    // Made nonisolated for easier testing
    nonisolated public func simulateScreenSharing(_ isSharing: Bool) {
        simulatedScreenSharing.store(isSharing, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    // Custom debug description
    public nonisolated var debugDescription: String {
        "MockScreenShareDetector"
    }
}

/// A Swift 6 compatible mock implementation of DND manager using actors
@available(macOS 14.0, *)
public actor MockDNDManager: DNDManagerProtocol, CustomDebugStringConvertible {
    nonisolated private let activeModes = Synchronization.Atomic<[FocusMode: Bool]>([:])
    public static let focusModeChangedNotification = Notification.Name("MockFocusModeChangedNotification")
    
    public init() {
        var initialModes: [FocusMode: Bool] = [:]
        for mode in FocusMode.allCases {
            initialModes[mode] = false
        }
        activeModes.store(initialModes, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    #if swift(>=6.0) && swift(<6.1)
    public func enableDoNotDisturb(options: FocusOptions) async throws -> Void {
    #else
    public func enableDoNotDisturb(options: FocusOptions) async throws(DNDError) {
    #endif
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[options.mode] = true
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Post notification (must be done on main thread)
        await MainActor.run {
            NotificationCenter.default.post(
                name: Self.focusModeChangedNotification,
                object: self,
                userInfo: ["mode": options.mode.rawValue, "active": true]
            )
        }
    }
    
    #if swift(>=6.0) && swift(<6.1)
    public func disableDoNotDisturb(mode: FocusMode) async throws -> Void {
    #else
    public func disableDoNotDisturb(mode: FocusMode) async throws(DNDError) {
    #endif
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[mode] = false
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Post notification (must be done on main thread)
        await MainActor.run {
            NotificationCenter.default.post(
                name: Self.focusModeChangedNotification,
                object: self,
                userInfo: ["mode": mode.rawValue, "active": false]
            )
        }
    }
    
    public func disableAllModes() async {
        var allInactive: [FocusMode: Bool] = [:]
        for mode in FocusMode.allCases {
            allInactive[mode] = false
        }
        activeModes.store(allInactive, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    public func isAnyModeActive() async -> Bool {
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        return modes.values.contains(true)
    }
    
    public func isModeActive(_ mode: FocusMode) async -> Bool {
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        return modes[mode] ?? false
    }
    
    // Swift 6 count(where:) method
    public func countActiveModes() async -> Int {
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        return modes.count { $0.value }
    }
    
    // Custom debug description
    nonisolated public var debugDescription: String {
        "MockDNDManager"
    }
} 
