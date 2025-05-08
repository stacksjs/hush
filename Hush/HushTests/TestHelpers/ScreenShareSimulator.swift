import Foundation
@testable import Hush

/// A class that helps test code by simulating screen sharing
class ScreenShareSimulator {
    /// Starts a screen recording using macOS built-in screen recording feature
    /// - Returns: True if the screen recording was successfully started, false otherwise
    static func startScreenRecording() -> Bool {
        // WARNING: This uses AppleScript, which may trigger permissions dialogs
        // when running tests. You'll need to grant permission for this to work.
        let script = """
        tell application "QuickTime Player"
            activate
            new screen recording
            tell application "System Events" to keystroke space
            delay 1
        end tell
        """
        
        return runAppleScript(script)
    }
    
    /// Stops any active screen recordings from QuickTime Player
    /// - Returns: True if the screen recording was successfully stopped, false otherwise
    static func stopScreenRecording() -> Bool {
        // Stop the screen recording by closing QuickTime
        let script = """
        tell application "QuickTime Player"
            if exists (document 1) then
                close document 1 saving no
            end if
            quit
        end tell
        """
        
        return runAppleScript(script)
    }
    
    /// Starts a Zoom meeting with screen sharing
    /// - Returns: True if Zoom was successfully launched with screen sharing, false otherwise
    static func startZoomScreenSharing() -> Bool {
        // This is hypothetical and would require Zoom to be installed
        // WARNING: This will actually launch Zoom if installed
        let script = """
        tell application "zoom.us"
            activate
        end tell
        """
        
        return runAppleScript(script)
    }
    
    /// Utility method to run AppleScript
    /// - Parameter script: The AppleScript to run
    /// - Returns: True if the script executed successfully, false otherwise
    private static func runAppleScript(_ script: String) -> Bool {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("Failed to execute AppleScript: \(error)")
            return false
        }
        
        return true
    }
} 