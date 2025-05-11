import Foundation
import AppKit
import Synchronization

// MARK: - Swift 6 DNDManager Implementation

// MARK: - DNDManager Implementation

/// DNDManager handles enabling and disabling macOS's Do Not Disturb (Focus) mode
/// Uses Swift 6 actors for thread safety and typed throws for precise error handling
@available(macOS 14.0, *)
public actor DNDManager: DNDManagerProtocol, CustomDebugStringConvertible {
    // Properties to track state with improved thread safety
    nonisolated private let activeModes = Synchronization.Atomic<[FocusMode: Bool]>([:])
    private var activeTimers: [FocusMode: Timer] = [:]
    private var lastError: DNDError?
    private var lastSuccessTime: Date?
    
    // Constants
    public static let focusModeChangedNotification = Notification.Name("HushFocusModeChangedNotification")
    public static let focusErrorNotification = Notification.Name("HushFocusErrorNotification")
    
    // Initialize with default detection of available modes
    public init() {
        // Set initial state for all modes as inactive
        var initialModes: [FocusMode: Bool] = [:]
        for mode in FocusMode.allCases {
            initialModes[mode] = false
        }
        activeModes.store(initialModes, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    // MARK: - Error Handling Helpers
    
    // Helper method to handle enable errors
    private func handleEnableError(_ error: Error, for options: FocusOptions) async {
        // Update active modes to reflect the failure
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[options.mode] = false
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Convert to DNDError for consistent error handling
        let dndError = DNDError.scriptExecutionFailed(error.localizedDescription)
        lastError = dndError
        
        // Post notification about error
        await MainActor.run {
            NotificationCenter.default.post(
                name: Self.focusErrorNotification, 
                object: self,
                userInfo: ["mode": options.mode.rawValue, "error": dndError.localizedDescription]
            )
        }
    }
    
    // Helper method to handle disable errors
    private func handleDisableError(_ error: Error, for mode: FocusMode) async {
        // Convert to DNDError for consistent error handling
        let dndError = DNDError.scriptExecutionFailed(error.localizedDescription)
        lastError = dndError
        
        // Post notification about error
        await MainActor.run {
            NotificationCenter.default.post(
                name: Self.focusErrorNotification, 
                object: self,
                userInfo: ["mode": mode.rawValue, "error": dndError.localizedDescription]
            )
        }
    }
    
    // MARK: - Core Functionality
    
    // Enable Do Not Disturb mode with options
    #if swift(>=6.0) && swift(<6.1)
    public func enableDoNotDisturb(options: FocusOptions) async throws -> Void {
        // Update active modes atomically
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[options.mode] = true
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Post notification about starting to change mode (on main thread)
        await MainActor.run {
            NotificationCenter.default.post(
                name: Self.focusModeChangedNotification, 
                object: self,
                userInfo: ["mode": options.mode.rawValue, "active": true, "starting": true]
            )
        }
        
        // Cancel any existing timer for this mode
        if let timer = activeTimers[options.mode] {
            timer.invalidate()
            activeTimers[options.mode] = nil
        }
        
        // Create AppleScript based on the selected mode
        let appleScript = createFocusEnableScript(for: options.mode)
        
        // Run the script
        do {
            try await runAppleScriptWithErrorHandling(appleScript)
            lastSuccessTime = Date()
            
            // Set a timer to disable after duration if specified
            if let duration = options.duration {
                // Creating timers must be done on the main thread
                await MainActor.run {
                    let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                        // Must explicitly create a Task since timer callback isn't async
                        Task {
                            // Using try? since the timer callback can't propagate errors
                            if let self {
                                try? await self.disableDoNotDisturb(mode: options.mode)
                            }
                        }
                    }
                    
                    // Access activeTimers on the actor's isolation context
                    Task {
                        await self.storeTimer(timer, forMode: options.mode)
                    }
                }
            }
            
            // Post notification about successful mode change
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Self.focusModeChangedNotification, 
                    object: self,
                    userInfo: ["mode": options.mode.rawValue, "active": true, "success": true]
                )
            }
        } catch {
            await handleEnableError(error, for: options)
            throw error
        }
    }
    #else
    public func enableDoNotDisturb(options: FocusOptions) async throws(DNDError) {
        // Update active modes atomically
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[options.mode] = true
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Post notification about starting to change mode (on main thread)
        await MainActor.run {
            NotificationCenter.default.post(
                name: Self.focusModeChangedNotification, 
                object: self,
                userInfo: ["mode": options.mode.rawValue, "active": true, "starting": true]
            )
        }
        
        // Cancel any existing timer for this mode
        if let timer = activeTimers[options.mode] {
            timer.invalidate()
            activeTimers[options.mode] = nil
        }
        
        // Create AppleScript based on the selected mode
        let appleScript = createFocusEnableScript(for: options.mode)
        
        // Run the script
        do {
            try await runAppleScriptWithErrorHandling(appleScript)
            lastSuccessTime = Date()
            
            // Set a timer to disable after duration if specified
            if let duration = options.duration {
                // Creating timers must be done on the main thread
                await MainActor.run {
                    let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                        // Must explicitly create a Task since timer callback isn't async
                        Task {
                            // Using try? since the timer callback can't propagate errors
                            if let self {
                                try? await self.disableDoNotDisturb(mode: options.mode)
                            }
                        }
                    }
                    
                    // Access activeTimers on the actor's isolation context
                    Task {
                        await self.storeTimer(timer, forMode: options.mode)
                    }
                }
            }
            
            // Post notification about successful mode change
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Self.focusModeChangedNotification, 
                    object: self,
                    userInfo: ["mode": options.mode.rawValue, "active": true, "success": true]
                )
            }
        } catch {
            await handleEnableError(error, for: options)
            throw DNDError.scriptExecutionFailed(error.localizedDescription)
        }
    }
    #endif
    
    // Helper method to store timer in the actor's context
    private func storeTimer(_ timer: Timer, forMode mode: FocusMode) {
        activeTimers[mode] = timer
    }
    
    // Disable a specific Do Not Disturb mode
    #if swift(>=6.0) && swift(<6.1)
    public func disableDoNotDisturb(mode: FocusMode) async throws -> Void {
        // Update active modes atomically
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[mode] = false
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Cancel any timer for this mode
        if let timer = activeTimers[mode] {
            timer.invalidate()
            activeTimers[mode] = nil
        }
        
        // Create and run AppleScript to disable the mode
        let appleScript = createFocusDisableScript(for: mode)
        
        do {
            try await runAppleScriptWithErrorHandling(appleScript)
            
            // Post notification about mode change
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Self.focusModeChangedNotification, 
                    object: self,
                    userInfo: ["mode": mode.rawValue, "active": false]
                )
            }
        } catch {
            await handleDisableError(error, for: mode)
            throw error
        }
    }
    #else
    public func disableDoNotDisturb(mode: FocusMode) async throws(DNDError) {
        // Update active modes atomically
        var modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        modes[mode] = false
        activeModes.store(modes, ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Cancel any timer for this mode
        if let timer = activeTimers[mode] {
            timer.invalidate()
            activeTimers[mode] = nil
        }
        
        // Create and run AppleScript to disable the mode
        let appleScript = createFocusDisableScript(for: mode)
        
        do {
            try await runAppleScriptWithErrorHandling(appleScript)
            
            // Post notification about mode change
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Self.focusModeChangedNotification, 
                    object: self,
                    userInfo: ["mode": mode.rawValue, "active": false]
                )
            }
        } catch {
            await handleDisableError(error, for: mode)
            throw DNDError.scriptExecutionFailed(error.localizedDescription)
        }
    }
    #endif
    
    // Disable all active Focus modes
    public func disableAllModes() async {
        // Get a copy of the current modes
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        
        // Disable each active mode
        for (mode, isActive) in modes where isActive {
            do {
                try await disableDoNotDisturb(mode: mode)
            } catch {
                // Log but continue with other modes
                print("Failed to disable \(mode.rawValue): \(error.localizedDescription)")
            }
        }
        
        // Ensure our state is clean
        var allInactive: [FocusMode: Bool] = [:]
        for mode in FocusMode.allCases {
            allInactive[mode] = false
        }
        activeModes.store(allInactive, ordering: Synchronization.MemoryOrdering.relaxed)
    }
    
    // Check if any Focus mode is active
    public func isAnyModeActive() async -> Bool {
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        return modes.values.contains(true)
    }
    
    // Check if a specific mode is active
    public func isModeActive(_ mode: FocusMode) async -> Bool {
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        return modes[mode] ?? false
    }
    
    // MARK: - Helper Methods
    
    // Create AppleScript to enable a Focus mode
    private func createFocusEnableScript(for mode: FocusMode) -> String {
        // This is a simplified version - real implementation would have mode-specific scripts
        return """
        tell application "System Events"
            tell process "Control Center"
                -- Open Focus menu
                click menu bar item "Focus" of menu bar 1
                delay 0.5
                
                -- Click on the specific focus mode
                click button "\(mode.rawValue)" of window 1
                delay 0.5
                
                -- Click to enable for 1 hour (or equivalent based on UI)
                click button "1 Hour" of window 1
            end tell
        end tell
        """
    }
    
    // Create AppleScript to disable a Focus mode
    private func createFocusDisableScript(for mode: FocusMode) -> String {
        // This is a simplified version - real implementation would have mode-specific scripts
        return """
        tell application "System Events"
            tell process "Control Center"
                -- Open Focus menu
                click menu bar item "Focus" of menu bar 1
                delay 0.5
                
                -- If the mode is active, click to disable it
                if exists (button "\(mode.rawValue)" of window 1 whose value is 1) then
                    click button "\(mode.rawValue)" of window 1
                end if
            end tell
        end tell
        """
    }
    
    // Run AppleScript with proper error handling
    #if swift(>=6.0) && swift(<6.1)
    private func runAppleScriptWithErrorHandling(_ script: String) async throws -> Void {
        // Create AppleScript
        let appleScript = NSAppleScript(source: script)
        
        // Execute the script on the MainActor since NSAppleScript isn't thread-safe
        let (success, errorMessage, errorCode) = await MainActor.run { () -> (Bool, String, Int) in
            var errorDict: NSDictionary?
            let result = appleScript?.executeAndReturnError(&errorDict)
            
            // Extract relevant error info as simple types
            let errorMsg = errorDict?["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            let code = errorDict?["NSAppleScriptErrorNumber"] as? Int ?? -1
            
            return (result != nil, errorMsg, code)
        }
        
        // Handle errors with the simple types
        if !success {
            // Map to appropriate DNDError type
            switch errorCode {
            case -1719: // Permission error
                throw DNDError.permissionDenied
            case -1728: // Service unavailable
                throw DNDError.systemServiceUnavailable
            default:
                throw DNDError.scriptExecutionFailed(errorMessage)
            }
        }
    }
    #else
    private func runAppleScriptWithErrorHandling(_ script: String) async throws(DNDError) {
        // Create AppleScript
        let appleScript = NSAppleScript(source: script)
        
        // Execute the script on the MainActor since NSAppleScript isn't thread-safe
        let (success, errorMessage, errorCode) = await MainActor.run { () -> (Bool, String, Int) in
            var errorDict: NSDictionary?
            let result = appleScript?.executeAndReturnError(&errorDict)
            
            // Extract relevant error info as simple types
            let errorMsg = errorDict?["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            let code = errorDict?["NSAppleScriptErrorNumber"] as? Int ?? -1
            
            return (result != nil, errorMsg, code)
        }
        
        // Handle errors with the simple types
        if !success {
            // Map to appropriate DNDError type
            switch errorCode {
            case -1719: // Permission error
                throw DNDError.permissionDenied
            case -1728: // Service unavailable
                throw DNDError.systemServiceUnavailable
            default:
                throw DNDError.scriptExecutionFailed(errorMessage)
            }
        }
    }
    #endif
    
    // MARK: - Debug Support
    
    // Implement debugDescription without the macro
    nonisolated public var debugDescription: String {
        "DNDManager"
    }
    
    // Helper method to get active modes description
    nonisolated private func describeActiveModes() -> String {
        // Now that activeModes is nonisolated, we can access it directly
        let modesSnapshot = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        let activeModesDesc = modesSnapshot.filter { $0.value }.map { $0.key.rawValue }.joined(separator: ", ")
        return activeModesDesc.isEmpty ? "none" : activeModesDesc
    }
    
    // MARK: - Convenience Methods
    
    /// Get available focus modes on the system
    public func getAvailableFocusModes() async -> [FocusMode] {
        return FocusMode.allCases
    }
    
    /// Enable a focus mode with the given ID
    public func enableFocusMode(options: FocusOptions) async throws -> Bool {
        try await enableDoNotDisturb(options: options)
        return true
    }
    
    /// Disable a focus mode with the given ID
    public func disableFocusMode(id: String) async throws -> Bool {
        if let mode = FocusMode.allCases.first(where: { $0.rawValue.lowercased().contains(id.lowercased()) }) {
            try await disableDoNotDisturb(mode: mode)
            return true
        }
        return false
    }
    
    /// Check if a mode with the given ID is active
    public func isModeActive(id: String) async -> Bool {
        if let mode = FocusMode.allCases.first(where: { $0.rawValue.lowercased().contains(id.lowercased()) }) {
            return await isModeActive(mode)
        }
        return false
    }
    
    /// Count active modes using Swift 6's count(where:) method
    public func countActiveModes() async -> Int {
        let modes = activeModes.load(ordering: Synchronization.MemoryOrdering.relaxed)
        return modes.count { $0.value }
    }
}