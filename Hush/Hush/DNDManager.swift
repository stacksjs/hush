import Foundation
import AppKit

// MARK: - Focus Mode Definitions

// Enum for Focus modes
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

// Options for Focus management
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

// DNDManager handles enabling and disabling macOS's Do Not Disturb (Focus) mode
class DNDManager: NSObject {
    // Properties to track state
    private var activeModes: [FocusMode: Bool] = [:]
    private var activeTimers: [FocusMode: Timer] = [:]
    private var lastError: Error?
    private var lastSuccessTime: Date?
    
    // Notification center for sending state updates
    private let notificationCenter = NotificationCenter.default
    
    // Constants
    static let focusModeChangedNotification = Notification.Name("HushFocusModeChangedNotification")
    static let focusErrorNotification = Notification.Name("HushFocusErrorNotification")
    
    // Initialize with default detection of available modes
    override init() {
        super.init()
        // Set initial state for all modes as inactive
        for mode in FocusMode.allCases {
            activeModes[mode] = false
        }
    }
    
    // Enable Do Not Disturb mode with options
    func enableDoNotDisturb(options: FocusOptions = FocusOptions()) {
        // Save which mode we're activating
        activeModes[options.mode] = true
        
        // Post notification about starting to change mode
        notificationCenter.post(name: DNDManager.focusModeChangedNotification, 
                                object: self,
                                userInfo: ["mode": options.mode.rawValue, "active": true, "starting": true])
        
        // Cancel any existing timer for this mode
        activeTimers[options.mode]?.invalidate()
        activeTimers[options.mode] = nil
        
        // Create AppleScript based on the selected mode
        let appleScript = createFocusEnableScript(for: options.mode)
        
        // Run the script
        do {
            try runAppleScriptWithErrorHandling(appleScript)
            lastSuccessTime = Date()
            
            // Set a timer to disable after duration if specified
            if let duration = options.duration {
                let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.disableDoNotDisturb(mode: options.mode)
                }
                activeTimers[options.mode] = timer
            }
            
            // Post notification about successful mode change
            notificationCenter.post(name: DNDManager.focusModeChangedNotification, 
                                    object: self,
                                    userInfo: ["mode": options.mode.rawValue, "active": true, "success": true])
        } catch {
            lastError = error
            
            // Post notification about error
            notificationCenter.post(name: DNDManager.focusErrorNotification, 
                                    object: self,
                                    userInfo: ["mode": options.mode.rawValue, "error": error.localizedDescription])
            
            // Try alternate method as fallback
            legacyToggleDoNotDisturb(enable: true)
        }
    }
    
    // Disable a specific Focus mode
    func disableDoNotDisturb(mode: FocusMode = .standard) {
        // Update state
        activeModes[mode] = false
        
        // Post notification about starting to change mode
        notificationCenter.post(name: DNDManager.focusModeChangedNotification, 
                                object: self,
                                userInfo: ["mode": mode.rawValue, "active": false, "starting": true])
        
        // Cancel any active timer
        activeTimers[mode]?.invalidate()
        activeTimers[mode] = nil
        
        // Create the appropriate AppleScript
        let appleScript = createFocusDisableScript(for: mode)
        
        // Run the script
        do {
            try runAppleScriptWithErrorHandling(appleScript)
            lastSuccessTime = Date()
            
            // Post notification about successful mode change
            notificationCenter.post(name: DNDManager.focusModeChangedNotification, 
                                    object: self,
                                    userInfo: ["mode": mode.rawValue, "active": false, "success": true])
        } catch {
            lastError = error
            
            // Post notification about error
            notificationCenter.post(name: DNDManager.focusErrorNotification, 
                                    object: self,
                                    userInfo: ["mode": mode.rawValue, "error": error.localizedDescription])
            
            // Try alternate method as fallback
            legacyToggleDoNotDisturb(enable: false)
        }
    }
    
    // Disable all active Focus modes
    func disableAllModes() {
        for mode in FocusMode.allCases where activeModes[mode] == true {
            disableDoNotDisturb(mode: mode)
        }
    }
    
    // Check if any Focus mode is active
    func isAnyModeActive() -> Bool {
        return activeModes.values.contains(true)
    }
    
    // Check if a specific mode is active
    func isModeActive(_ mode: FocusMode) -> Bool {
        return activeModes[mode] ?? false
    }
    
    // Get the most recent error if any
    func getLastError() -> Error? {
        return lastError
    }
    
    // MARK: - Private Methods
    
    // Run an AppleScript with error handling
    private func runAppleScriptWithErrorHandling(_ script: String) throws {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            throw NSError(
                domain: "HushDNDManager",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to run AppleScript: \(error[NSAppleScript.errorMessage] ?? "Unknown error")"
                ]
            )
        }
    }
    
    // Create the appropriate AppleScript for enabling Focus mode
    private func createFocusEnableScript(for mode: FocusMode) -> String {
        let modeName = mode.displayName
        
        return """
        tell application "System Events"
            tell process "Control Center"
                try
                    # Try to turn on \(modeName) if it exists and is accessible
                    click menu bar item "Focus" of menu bar 1
                    delay 0.5
                end try
            end tell
        end tell
        """
    }
    
    // Create the appropriate AppleScript for disabling Focus mode
    private func createFocusDisableScript(for mode: FocusMode) -> String {
        let modeName = mode.displayName
        
        return """
        tell application "System Events"
            tell process "Control Center"
                try
                    # Try to turn off \(modeName) if it exists and is accessible
                    click menu bar item "Focus" of menu bar 1
                    delay 0.5
                end try
            end tell
        end tell
        """
    }
    
    // Legacy method for older macOS versions
    private func legacyToggleDoNotDisturb(enable: Bool) {
        // Fallback method for controlling DND via defaults command
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        
        if enable {
            task.arguments = ["write", "com.apple.controlcenter", "NSStatusItem Visible FocusModes" , "-bool", "true"]
        } else {
            task.arguments = ["write", "com.apple.controlcenter", "NSStatusItem Visible FocusModes" , "-bool", "false"]
        }
        
        task.launch()
    }
} 
