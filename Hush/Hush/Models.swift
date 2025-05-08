import Foundation

// MARK: - Data Models

// Preferences model using string-based storage for Focus modes
struct Preferences: Codable {
    // General settings
    var isFirstLaunch = true
    var launchAtLogin = false
    var detectionIntervalSeconds: TimeInterval = 1.0
    
    // Notification settings
    var showNotifications = true
    var showErrorNotifications = true
    var enableNotificationSound = false
    
    // Focus settings
    var selectedFocusModeRawValue: String = "Focus"
    var selectedDuration: TimeInterval? = nil  // nil means until screen sharing ends
    var keepEnabledAfterSharing = false
    
    init() {}
}

// Statistics model
struct Statistics: Codable {
    var screenSharingActivations: Int = 0
    var sessionCount: Int = 0
    var totalActiveTime: TimeInterval = 0
    var lastActivated: Date? = nil
    var lastDeactivated: Date? = nil
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
