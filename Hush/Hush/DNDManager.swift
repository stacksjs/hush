import Foundation
import AppKit

// Enum for Focus modes
enum FocusMode: String, CaseIterable, Codable {
    case standard = "Focus"
    case doNotDisturb = "Do Not Disturb" 
    case work = "Work"
    case personal = "Personal"
    case sleep = "Sleep"
    
    var displayName: String {
        return self.rawValue
    }
}

// Options for Focus management
struct FocusOptions {
    var mode: FocusMode = .standard
    var duration: TimeInterval? = nil  // nil means indefinite, otherwise in seconds
    var enableSound: Bool = false
}

// DNDManager handles enabling and disabling macOS's Do Not Disturb (Focus) mode
@objc class DNDManager: NSObject {
    // Properties to track state
    private var activeModes: [FocusMode: Bool] = [:]
    private var activeTimers: [FocusMode: Timer] = [:]
    private var lastError: Error?
    private var lastSuccessTime: Date?
    
    // Notification center for sending state updates
    private let notificationCenter = NotificationCenter.default
    
    // Constants
    @objc static let focusModeChangedNotification = Notification.Name("HushFocusModeChangedNotification")
    @objc static let focusErrorNotification = Notification.Name("HushFocusErrorNotification")
    
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
                    
                    # Try to select the specific mode if needed
                    if "\(modeName)" is not "Focus" then
                        # For specific modes, need to navigate the UI differently
                        if exists menu item "\(modeName)" of menu 1 of menu bar item "Focus" of menu bar 1 then
                            click menu item "\(modeName)" of menu 1 of menu bar item "Focus" of menu bar 1
                            delay 0.5
                        end if
                    end if
                    
                    # Turn on the mode
                    if exists button "Turn On" of window 1 then
                        click button "Turn On" of window 1
                    end if
                on error
                    # If that fails, try to use Control Center
                    try
                        click menu bar item "Control Center" of menu bar 1
                        delay 0.5
                        click button "Focus" of window "Control Center"
                        delay 0.5
                        
                        # Try to select the specific mode if needed
                        if "\(modeName)" is not "Focus" then
                            # For specific modes, need to navigate the Control Center UI differently
                            if exists menu item "\(modeName)" of menu 1 of window "Control Center" then
                                click menu item "\(modeName)" of menu 1 of window "Control Center"
                                delay 0.5
                            end if
                        end if
                        
                        # Turn on the mode
                        if exists button "Turn On" of window "Control Center" then
                            click button "Turn On" of window "Control Center"
                        end if
                    end try
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
                    
                    # Try to select the specific mode if needed
                    if "\(modeName)" is not "Focus" then
                        # For specific modes, need to navigate the UI differently
                        if exists menu item "\(modeName)" of menu 1 of menu bar item "Focus" of menu bar 1 then
                            click menu item "\(modeName)" of menu 1 of menu bar item "Focus" of menu bar 1
                            delay 0.5
                        end if
                    end if
                    
                    # Turn off the mode
                    if exists button "Turn Off" of window 1 then
                        click button "Turn Off" of window 1
                    end if
                on error
                    # If that fails, try to use Control Center
                    try
                        click menu bar item "Control Center" of menu bar 1
                        delay 0.5
                        click button "Focus" of window "Control Center"
                        delay 0.5
                        
                        # Try to select the specific mode if needed
                        if "\(modeName)" is not "Focus" then
                            # For specific modes, need to navigate the Control Center UI differently
                            if exists menu item "\(modeName)" of menu 1 of window "Control Center" then
                                click menu item "\(modeName)" of menu 1 of window "Control Center"
                                delay 0.5
                            end if
                        end if
                        
                        # Turn off the mode
                        if exists button "Turn Off" of window "Control Center" then
                            click button "Turn Off" of window "Control Center"
                        end if
                    end try
                end try
            end tell
        end tell
        """
    }
    
    // Alternative implementation for older macOS versions (pre-Monterey)
    // This can be used if needed for backward compatibility
    func legacyToggleDoNotDisturb(enable: Bool) {
        let script = """
        tell application "System Events"
            tell process "SystemUIServer"
                try
                    key down option
                    click menu bar item 1 of menu bar 1
                    key up option
                on error
                    key up option
                end try
            end tell
        end tell
        """
        
        do {
            try runAppleScriptWithErrorHandling(script)
        } catch {
            lastError = error
            print("Legacy AppleScript error: \(error)")
        }
    }
    
    // Helper method to run AppleScript with error handling
    private func runAppleScriptWithErrorHandling(_ script: String) throws {
        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        
        guard let _ = appleScript?.executeAndReturnError(&errorInfo) else {
            if let errorInfo = errorInfo {
                let error = NSError(
                    domain: "HushAppleScriptErrorDomain",
                    code: errorInfo[NSAppleScript.errorNumber] as? Int ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"]
                )
                throw error
            } else {
                throw NSError(
                    domain: "HushAppleScriptErrorDomain",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to execute AppleScript"]
                )
            }
        }
    }
} 