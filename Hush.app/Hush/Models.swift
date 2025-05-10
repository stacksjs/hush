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
    
    // Optional fields for future expansion
    var lastActiveFocusMode: String?
    var customFocusModes: [String]?
}

// Statistics model
struct Statistics: Codable {
    /// The number of times screen sharing has been activated
    var screenSharingActivations = 0
    
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
