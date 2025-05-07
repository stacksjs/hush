import Foundation

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
    var selectedFocusMode: FocusMode = .standard
    var selectedDuration: TimeInterval? = nil  // nil means until screen sharing ends
    var keepEnabledAfterSharing = false
} 