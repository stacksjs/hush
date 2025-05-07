import Foundation

struct Statistics: Codable {
    var screenSharingActivations: Int = 0
    var sessionCount: Int = 0
    var totalActiveTime: TimeInterval = 0
    var lastActivated: Date? = nil
    var lastDeactivated: Date? = nil
    var appInstallDate: Date = Date()
    
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