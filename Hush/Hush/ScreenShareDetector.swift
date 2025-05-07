import Foundation
import CoreGraphics
import AppKit

@objc class ScreenShareDetector: NSObject {
    // Properties for monitoring
    private var isScreenBeingCaptured = false
    private var captureDetectionTimer: Timer?
    private var windowDetectionTimer: Timer?
    private var shouldAutoStart: Bool
    
    // Initialize with optional auto-start
    override init() {
        self.shouldAutoStart = true
        super.init()
        if shouldAutoStart {
            startMonitoring()
        }
    }
    
    init(autoStart: Bool) {
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
        startCaptureStatusTimer()
        startWindowMonitoringTimer()
    }
    
    // Stop all monitoring methods
    func stopMonitoring() {
        captureDetectionTimer?.invalidate()
        captureDetectionTimer = nil
        
        windowDetectionTimer?.invalidate()
        windowDetectionTimer = nil
    }
    
    // Method to detect if the screen is being shared
    func isScreenSharing() -> Bool {
        return isSystemScreenSharing() || 
               isRunningScreenSharingApp() || 
               isScreenBeingCaptured ||
               hasScreenSharingWindows()
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
            "com.mainconcept.screenrecorder",   // Screen Recorder
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
} 