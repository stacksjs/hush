import Foundation

// MARK: - Data Models

// Preferences model using string-based storage for Focus modes
struct Preferences: Codable {
    /// Whether to show a notification when Do Not Disturb is enabled/disabled
    var showNotifications = true
    
    /// Whether to enable notification sounds
    var enableNotificationSound = true
    
    /// Whether to show error notifications
    var showErrorNotifications = true
    
    /// Whether this is the first launch of the app
    var isFirstLaunch = true
    
    /// Whether to keep Do Not Disturb enabled after screen sharing ends
    var keepEnabledAfterSharing = false
    
    /// The raw value of the selected focus mode
    var selectedFocusModeRawValue = "Focus"
    
    /// The selected duration in seconds, or nil for indefinite
    var selectedDuration: TimeInterval?
    
    /// The detection interval in seconds (how often to check for screen sharing)
    var detectionIntervalSeconds = 1.0
    
    /// Whether to launch the app automatically at login
    var launchAtLogin = false
    
    /// Whether the Zoom compatibility warning has been shown
    var hasShownZoomWarning = false
    
    /// When the Zoom warning was last shown
    var lastZoomWarningTime: Date?
    
    /// Whether to never show the Zoom warning again
    var neverShowZoomWarning = true
    
    /// Whether to automatically enable DND when Zoom is detected
    var automaticallyEnable = true
    
    /// Maximum number of retries for DND activation
    var maxDNDActivationRetries = 3
    
    /// Whether to prioritize terminal commands over AppleScript
    var useTerminalCommandsPrimarily = true
    
    /// Timeout in seconds for DND activation verification
    var dndActivationTimeoutSeconds = 2.0
    
    /// Whether to use additional DND verification methods
    var useAdditionalVerification = true
    
    /// Number of seconds to wait between detection checks
    var zoomDetectionIntervalSeconds = 5.0
    
    // Optional fields for future expansion
    var lastActiveFocusMode: String?
    var customFocusModes: [String]?
}

// Statistics model
struct Statistics: Codable {
    /// The number of times screen sharing has been activated
    var screenSharingActivations = 0
    
    /// The number of times Zoom has triggered DND activation
    var zoomActivations = 0
    
    /// The number of times the user has manually activated DND
    var manualActivations = 0
    
    /// The number of times the user has manually disabled DND
    var manualDisables = 0
    
    /// The total active time in seconds
    var totalActiveTime: TimeInterval = 0
    
    /// The number of screen sharing sessions
    var sessionCount = 0
    
    /// The timestamp when Do Not Disturb was last activated
    var lastActivated: Date?
    
    /// The timestamp when Do Not Disturb was last deactivated
    var lastDeactivated: Date?
    
    var appInstallDate: Date = Date()
    
    init() {}
    
    // Computed properties (not stored)
    var formattedTotalActiveTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter.string(from: totalActiveTime) ?? "0 minutes"
    }
    
    var averageSessionDuration: TimeInterval {
        return sessionCount > 0 ? totalActiveTime / Double(sessionCount) : 0
    }
    
    var formattedAverageSessionDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: averageSessionDuration) ?? "0s"
    }
}
