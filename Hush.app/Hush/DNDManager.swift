import Foundation
import AppKit
import UserNotifications

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
    public var duration: TimeInterval?  // nil means indefinite, otherwise in seconds
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
        
        // PRIMARY APPROACH: Use terminal commands (most reliable)
        let success = enableDNDWithTerminalCommands()
        print("Terminal command approach: \(success ? "succeeded" : "failed")")
        
        // Only try other approaches if terminal commands failed
        if !success {
            // SECONDARY APPROACH: Try AppleScript
            try? runAppleScriptWithErrorHandling(createFocusEnableScript(for: options.mode))
        }
        
        // Set timer for duration if specified
        if let duration = options.duration {
            let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.disableDoNotDisturb(mode: options.mode)
            }
            activeTimers[options.mode] = timer
        }
        
        // Post notification about successful mode change after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Verify DND is actually enabled
            let isEnabled = self.isDNDEnabled()
            
            self.notificationCenter.post(
                name: DNDManager.focusModeChangedNotification, 
                object: self,
                userInfo: [
                    "mode": options.mode.rawValue, 
                    "active": true, 
                    "success": isEnabled
                ]
            )
            
            // If not enabled, try one more time
            if !isEnabled {
                print("DNDManager: DND not enabled after first attempt, trying again...")
                let _ = self.enableDNDWithTerminalCommands()
            }
            
            // Update last successful time
            self.lastSuccessTime = Date()
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
        
        // PRIMARY APPROACH: Use terminal commands (most reliable)
        let success = disableDNDWithTerminalCommands()
        print("Terminal command approach: \(success ? "succeeded" : "failed")")
        
        // Only try other approaches if terminal commands failed
        if !success {
            // SECONDARY APPROACH: Try AppleScript
            try? runAppleScriptWithErrorHandling(createFocusDisableScript(for: mode))
        }
        
        // Post notification about successful mode change after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Update success time
            self.lastSuccessTime = Date()
            
            // Post notification
            self.notificationCenter.post(
                name: DNDManager.focusModeChangedNotification, 
                object: self,
                userInfo: ["mode": mode.rawValue, "active": false, "success": true]
            )
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
        
        // Use a simpler, more direct approach with just the essential actions
        return """
        tell application "System Events"
            -- First try direct approach with Focus menu
            try
                -- Click the Focus menu
                click menu bar item "Focus" of menu bar 1
                delay 0.3
                
                -- Press the specific mode button if found
                if exists button "\(modeName)" of window 1 then
                    click button "\(modeName)" of window 1
                    delay 0.3
                    -- Select the first duration option we find
                    if exists button "For 1 hour" of window 1 then
                        click button "For 1 hour" of window 1
                    else if exists button "Until this evening" of window 1 then
                        click button "Until this evening" of window 1
                    else if exists button "Until turned off" of window 1 then
                        click button "Until turned off" of window 1
                    else if exists button "1 Hour" of window 1 then
                        click button "1 Hour" of window 1
                    end if
                    return true
                end if
            end try
            
            -- If first try failed, attempt with control center
            try
                tell application "SystemUIServer"
                    -- Try to click control center 
                    click menu bar item "Control Center" of menu bar 1
                    delay 0.3
                end tell
                
                -- Try to click Focus mode
                if exists button "Focus" of window "Control Center" then
                    click button "Focus" of window "Control Center"
                    delay 0.3
                    
                    -- Try to click specific mode
                    if exists button "\(modeName)" of window "Control Center" then
                        click button "\(modeName)" of window "Control Center"
                        return true
                    end if
                end if
            end try
            
            -- Last try - directly with Do Not Disturb as fallback
            try
                -- Try direct Do Not Disturb toggle
                if exists menu bar item "Do Not Disturb" of menu bar 1 then
                    click menu bar item "Do Not Disturb" of menu bar 1
                    return true
                end if
            end try
            
            -- Try the menu bar extra directly
            try
                tell process "Control Center"
                    click menu bar item "Control Center" of menu bar 1
                    delay 0.3
                    click button "Focus" of group 1 of window "Control Center"
                    delay 0.3
                    click button "\(modeName)" of window "Control Center"
                    return true
                end tell
            end try
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
    
    // Terminal command approach - most reliable for most macOS versions
    private func enableDNDWithTerminalCommands() -> Bool {
        print("Enabling Focus mode with terminal commands")
        
        // Run multiple commands for maximum compatibility across macOS versions
        let commands = [
            // 1. Main approach - NotificationCenterUI (older macOS)
            "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean true",
            
            // 2. NCPrefs approach (newer macOS)
            "defaults write com.apple.ncprefs dnd_prefs -dict userPref 1",
            
            // 3. AssertionServices approach
            "defaults write com.apple.AssertionServices assertionEnabled -bool true",
            
            // 4. Additional approach for macOS Ventura+
            "defaults write com.apple.controlcenter 'NSStatusItem Visible FocusMode' -bool true",
            
            // 5. Additional command for Big Sur/Monterey Focus mode
            "defaults write com.apple.controlcenter Focus -int 2",
            
            // 6. Additional approach for Sonoma+
            "defaults write com.apple.controlcenter FocusModes -dict-add activatedMode 'Do Not Disturb' previousModeName 'Do Not Disturb'",

            // 7. Restart NotificationCenter to apply changes (important!)
            "killall NotificationCenter &>/dev/null || true",
            
            // 8. Ensure Control Center is reloaded too for good measure
            "killall ControlCenter &>/dev/null || true"
        ]
        
        for command in commands {
            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", command]
            
            do {
                try task.run()
                task.waitUntilExit()
                print("Successfully executed: \(command)")
            } catch {
                print("Failed to execute command: \(command)")
                print("Error: \(error)")
                // Continue with other commands even if one fails
            }
        }
        
        // Give a bit of time for the changes to apply
        Thread.sleep(forTimeInterval: 0.5)
        
        // Verify DND is actually enabled
        let isEnabled = isDNDEnabled()
        
        // If not enabled, try one more approach as last resort
        if !isEnabled {
            print("First attempt failed - trying secondary approach")
            
            // Try an alternative direct command approach that's been successful in testing
            let fallbackCommands = [
                // Direct dnd_mode approach
                "defaults write com.apple.controlcenter 'NSStatusItem Visible Focus' -bool true",
                
                // Additional approach for Ventura+
                "defaults write com.apple.controlcenter.plist FocusModes -dict-add previousModeName 'Do Not Disturb'",
                
                // Additional approach for Sonoma
                "defaults write com.apple.controlcenter.plist focusMode -dict-add mode DoNotDisturb",
                
                // Restart services to apply
                "killall ControlCenter NotificationCenter &>/dev/null || true"
            ]
            
            for command in fallbackCommands {
                let task = Process()
                task.launchPath = "/bin/zsh"
                task.arguments = ["-c", command]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    print("Fallback command executed: \(command)")
                } catch {
                    print("Failed to execute fallback command: \(command)")
                }
            }
            
            // Sleep a bit longer for fallback commands
            Thread.sleep(forTimeInterval: 1.0)
            
            // Check again after fallback attempt
            return isDNDEnabled()
        }
        
        return isEnabled
    }
    
    // Check if DND is actually enabled
    private func isDNDEnabled() -> Bool {
        // Check several places where the setting might be stored
        let checkCommands = [
            "defaults -currentHost read com.apple.notificationcenterui doNotDisturb 2>/dev/null || echo '0'",
            "defaults read com.apple.ncprefs dnd_prefs 2>/dev/null || echo '{}'",
            "defaults read com.apple.AssertionServices assertionEnabled 2>/dev/null || echo '0'",
            // Additional checks for newer macOS versions
            "defaults read com.apple.controlcenter Focus 2>/dev/null || echo '0'",
            "defaults read com.apple.controlcenter.plist FocusModes 2>/dev/null || echo '{}'"
        ]
        
        for command in checkCommands {
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", command]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    if output.contains("1") || 
                       output.contains("userPref = 1") || 
                       output.contains("Focus = 2") ||
                       output.contains("previousModeName = \"Do Not Disturb\"") {
                        print("DND detected as enabled via: \(command)")
                        return true
                    }
                }
            } catch {
                print("Error checking DND status: \(error)")
            }
        }
        
        // If all checks fail, also try running an AppleScript to check UI state
        let appleScript = """
        tell application "System Events"
            try
                -- Try to check if Focus mode is active via menu bar
                if exists menu bar item "Focus" of menu bar 1 then
                    -- Focus icon in menu bar typically means it's active
                    return "1"
                end if
            end try
        end tell
        return "0"
        """
        
        if let script = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil, 
               let stringValue = result.stringValue,
               stringValue == "1" {
                print("DND detected as enabled via AppleScript UI check")
                return true
            }
        }
        
        print("DND appears to be disabled based on all checks")
        return false
    }
    
    // Terminal command approach to disable DND
    private func disableDNDWithTerminalCommands() -> Bool {
        print("Disabling Focus mode with terminal commands")
        
        // Run multiple commands for maximum compatibility across macOS versions
        let commands = [
            // 1. Main approach - NotificationCenterUI (older macOS)
            "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean false",
            
            // 2. NCPrefs approach (newer macOS)
            "defaults write com.apple.ncprefs dnd_prefs -dict userPref 0",
            
            // 3. AssertionServices approach
            "defaults write com.apple.AssertionServices assertionEnabled -bool false",
            
            // 4. Additional approach for macOS Ventura+
            "defaults write com.apple.controlcenter 'NSStatusItem Visible FocusMode' -bool false",
            
            // 5. Additional command for Big Sur/Monterey Focus mode
            "defaults write com.apple.controlcenter Focus -int 0",
            
            // 6. Restart NotificationCenter to apply changes (important!)
            "killall NotificationCenter &>/dev/null || true",
            
            // 7. Ensure Control Center is reloaded too for good measure
            "killall ControlCenter &>/dev/null || true"
        ]
        
        for command in commands {
            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", command]
            
            do {
                try task.run()
                task.waitUntilExit()
                print("Successfully executed: \(command)")
            } catch {
                print("Failed to execute command: \(command)")
                print("Error: \(error)")
                // Continue with other commands even if one fails
            }
        }
        
        // Give a bit of time for the changes to apply
        Thread.sleep(forTimeInterval: 0.5)
        
        // Verify DND is actually disabled
        return !isDNDEnabled()
    }
} 


