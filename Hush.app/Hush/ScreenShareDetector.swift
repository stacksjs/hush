import Foundation
import CoreGraphics
import AppKit
import Cocoa

@objc public class ScreenShareDetector: NSObject {
    // Properties for monitoring
    private var isScreenBeingCaptured = false
    private var captureDetectionTimer: Timer?
    private var windowDetectionTimer: Timer?
    private var shouldAutoStart: Bool
    private var isRunning = false
    
    // Initialize with optional auto-start
    override init() {
        self.shouldAutoStart = true
        super.init()
        if shouldAutoStart {
            startMonitoring()
        }
    }
    
    init(autoStart: Bool = false) {
        self.shouldAutoStart = autoStart
        super.init()
        if autoStart {
            startMonitoring()
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    // Start all monitoring methods
    func startMonitoring() {
        isRunning = true
        startCaptureStatusTimer()
        startWindowMonitoringTimer()
    }
    
    // Stop all monitoring methods
    func stopMonitoring() {
        captureDetectionTimer?.invalidate()
        captureDetectionTimer = nil
        
        windowDetectionTimer?.invalidate()
        windowDetectionTimer = nil
        
        isRunning = false
    }
    
    // Method to detect if the screen is being shared
    func isScreenSharing() -> Bool {
        // Check if screen is being shared via CGWindowServer
        let screenIsBeingShared = CGSHasScreensharingClient() || CGSSessionScreenIsShared()
        
        // Check if windows indicate screen sharing
        let windowsIndicateSharing = hasScreenSharingWindows()
        
        // Check Zoom screen sharing specifically
        let zoomIsScreenSharing = isZoomScreenSharing()
        
        // Check if apps that are likely to be screen sharing are running
        let appIndicatesSharing = isRunningScreenSharingApp()
        
        // Output debugging information
        print("ScreenShareDetector: system=\(screenIsBeingShared), windows=\(windowsIndicateSharing), zoom=\(zoomIsScreenSharing), apps=\(appIndicatesSharing)")
        
        // Return true if any of the detection methods indicate screen sharing
        return screenIsBeingShared || windowsIndicateSharing || zoomIsScreenSharing || appIndicatesSharing
    }
    
    // MARK: - Periodic Capture Status Check
    
    private func startCaptureStatusTimer() {
        // Check capture status every 2 seconds
        captureDetectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            // Query capture status directly
            let isCaptured = CGDisplayIsActive(CGMainDisplayID()) != 0 ||
                             CGDisplayIsOnline(CGMainDisplayID()) != 0 ||
                             CGDisplayIsInMirrorSet(CGMainDisplayID()) != 0
            
            self?.isScreenBeingCaptured = self?.isScreenBeingCaptured ?? false || isCaptured
            
            // Reset the captured flag periodically to avoid false positives
            // that persist after screen sharing has ended
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self?.isScreenBeingCaptured = false
            }
        }
    }
    
    // MARK: - Window Monitoring
    
    private func startWindowMonitoringTimer() {
        // Check for screen sharing windows every 2 seconds
        windowDetectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            _ = self?.hasScreenSharingWindows()
        }
    }
    
    private func hasScreenSharingWindows() -> Bool {
        // Get all on-screen windows
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        // Look for windows with names that indicate screen sharing
        let sharingWindowPatterns = [
            "Screen Sharing", "screen sharing", "Share Screen", "sharing your screen",
            "Zoom Meeting", "Meet", "Teams Meeting", "presenting", "Presentation",
            "Recording", "Broadcast"
        ]
        
        for window in windowList {
            if let name = window[kCGWindowName as String] as? String,
               let ownerName = window[kCGWindowOwnerName as String] as? String {
                
                // Check both window name and owner name against patterns
                for pattern in sharingWindowPatterns {
                    if name.contains(pattern) || ownerName.contains(pattern) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // Check if macOS's built-in screen sharing is active
    private func isSystemScreenSharing() -> Bool {
        // Get the CGSession dictionary which contains screen sharing status
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        
        // Check for screen sharing flags
        if let sharingState = dict["CGSSessionScreenIsShared"] as? Bool,
           sharingState {
            return true
        }
        
        // Check for remote control (someone controlling your Mac)
        if let remoteState = dict["kCGSSessionOnConsoleKey"] as? Bool,
           !remoteState {
            return true
        }
        
        return false
    }
    
    // Check if known screen sharing apps are running
    private func isRunningScreenSharingApp() -> Bool {
        let knownScreenSharingApps = [
            "com.apple.ScreenSharing",          // macOS Screen Sharing
            "com.microsoft.teams",              // Microsoft Teams
            "us.zoom.xos",                      // Zoom
            "com.google.Chrome",                // Chrome (for web conferencing)
            "com.microsoft.edgemac",            // Edge
            "com.apple.Safari",                 // Safari
            "com.brave.Browser",                // Brave
            "com.operasoftware.Opera",          // Opera
            "com.google.meetapp",               // Google Meet app
            "com.skype.skype",                  // Skype
            "com.microsoft.skypeforbusiness",   // Skype for Business
            "com.cisco.webexmeetingsapp",       // Webex
            "com.webex.meetingmanager",         // Webex classic
            "com.discord",                      // Discord
            "com.slack.Slack",                  // Slack
            "com.loom.desktop",                 // Loom
            "com.mmhmm.app",                    // mmhmm
            "com.teamviewer.TeamViewer",        // TeamViewer
            "com.apple.quicktimeplayer",        // QuickTime Player (sometimes used for recording)
            "com.obsproject.obs-studio",        // OBS Studio
            "com.electron.screenrecorderkit",   // Screen Recorder
            "com.adobe.captivate",              // Adobe Captivate
            "com.mainconcept.screenrecorder"    // Screen Recorder
        ]
        
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Check if any screen sharing app is running and has focus
        for app in runningApps {
            if let bundleID = app.bundleIdentifier,
               knownScreenSharingApps.contains(bundleID) {
                
                // For browsers, we could enhance this by checking if the browser
                // is accessing video capture permissions, but this would require
                // additional permissions in macOS
                
                // Check if app is active (has focus) to reduce false positives
                if app.isActive {
                    // Higher probability it's actually screen sharing
                    return true
                } else {
                    // Check process name for additional clues
                    if checkProcessActivityForScreenSharing(bundleID: bundleID) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private func checkProcessActivityForScreenSharing(bundleID: String) -> Bool {
        // For browsers and apps that might be screen sharing, do deeper inspection
        // This is a simplified implementation that could be enhanced with process inspection
        
        // For now, just consider certain apps as higher probability
        let highProbabilityApps = [
            "us.zoom.xos",                    // Zoom is almost always used for screen sharing
            "com.microsoft.teams",            // Teams is commonly used for screen sharing
            "com.obsproject.obs-studio",      // OBS is designed for screen recording/streaming
            "com.apple.ScreenSharing",        // Explicit screen sharing app
            "com.teamviewer.TeamViewer"       // Remote control app
        ]
        
        return highProbabilityApps.contains(bundleID)
    }
    
    // Check if Zoom is actively screen sharing - enhanced version
    private func isZoomScreenSharing() -> Bool {
        // Check if Zoom is running
        let runningApps = NSWorkspace.shared.runningApplications
        let zoomIsRunning = runningApps.contains(where: { $0.bundleIdentifier == "us.zoom.xos" })
        
        if !zoomIsRunning {
            return false
        }
        
        print("Zoom is running - checking for screen sharing indicators")
        
        // Method 1: Check for Zoom window names that indicate sharing
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        // Look specifically for Zoom sharing indicators
        let zoomSharingPatterns = [
            "You are screen sharing", 
            "Screen Share", 
            "Zoom Share",
            "Share Screen",
            "Screen Sharing",
            "Meeting",
            "is sharing",
            "is sharing screen",
            "is sharing your screen"
        ]
        
        for window in windowList {
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               ownerName.lowercased().contains("zoom") {
                
                if let name = window[kCGWindowName as String] as? String {
                    for pattern in zoomSharingPatterns {
                        if name.lowercased().contains(pattern.lowercased()) {
                            print("Found Zoom screen sharing window: \(name)")
                            return true
                        }
                    }
                    
                    // Debug: print all Zoom window names to help with pattern matching
                    print("Zoom window: \(name)")
                }
            }
        }
        
        // Method 2: Check for screen recording permission indicators
        // If Zoom is actively using screen recording permissions, it's likely screen sharing
        // This would require additional permissions and is not implemented here
        
        // Method 3: Look for specific window sizes or patterns that might indicate sharing
        for window in windowList {
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               ownerName.lowercased().contains("zoom") {
                
                // Check for share control bar which is typically small and at the top of the screen
                if let bounds = window[kCGWindowBounds as String] as? [String: Any],
                   let height = bounds["Height"] as? CGFloat,
                   let width = bounds["Width"] as? CGFloat,
                   let y = bounds["Y"] as? CGFloat {
                    
                    // Zoom share control bar is typically 30-50px high and near the top of the screen
                    if height < 60 && width > 300 && y < 100 {
                        print("Found potential Zoom share control bar")
                        return true
                    }
                }
            }
        }
        
        return false
    }
}

// Private CGSSession functions (for screen sharing detection)
private func CGSHasScreensharingClient() -> Bool {
    // This is a check for macOS screen sharing
    let connection = CGSMainConnectionID()
    var hasScreenSharingClient: Bool = false
    CGSGetScreensharingState(connection, &hasScreenSharingClient)
    return hasScreenSharingClient
}

private func CGSSessionScreenIsShared() -> Bool {
    // This is a check for third-party screen sharing
    let connection = CGSMainConnectionID()
    var isShared: Bool = false
    
    if let sessionDict = CGSSessionCopyCurrentDictionary(connection) as? [String: Any] {
        isShared = sessionDict[kCGSSessionScreenIsShared as String] as? Bool ?? false
    }
    
    return isShared
}

// CGSInternal functions (declaration only - these are private Apple APIs)
private func CGSMainConnectionID() -> CGSConnection { 
    return 0 // Stub - The actual function is part of private API
}

private func CGSGetScreensharingState(_ connection: CGSConnection, _ state: UnsafeMutablePointer<Bool>) -> Bool { 
    // Stub - This would need to be implemented via dlsym in a real app
    // For testing, we'll simulate it not being active
    state.pointee = false
    return true
}

private func CGSSessionCopyCurrentDictionary(_ connection: CGSConnection) -> AnyObject? { 
    // Stub - Would need to be implemented via dlsym
    // Return nil to indicate no screen sharing
    return nil
}

// Type aliases for CGSInternal types
typealias CGSConnection = UInt32
private let kCGSSessionScreenIsShared = "CGSSessionScreenIsShared" 
