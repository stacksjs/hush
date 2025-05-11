import Foundation
import Cocoa
import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    // UI Elements
    var statusBarItem: NSStatusItem!
    var statusMenu: NSMenu!
    var menuBarIcon: NSImage!
    var iconActive: NSImage!
    var iconInactive: NSImage!
    
    // Core functionality
    var screenShareDetector: ScreenShareDetector!
    var dndManager: DNDManager!
    
    // State tracking
    var isCurrentlyBlocking = false
    var lastScreenSharingState = false
    var isInTestMode = false
    var detectionTimer: Timer?
    var statistics = Statistics()
    var lastZoomCheckTime: Date?
    
    // Preferences
    var preferences = Preferences()
    var preferencesWindow: NSWindow?
    var statisticsWindow: NSWindow?
    
    // Define notification types for the app
    enum NotificationType {
        case doNotDisturbEnabled
        case doNotDisturbDisabled
        case screenShareDetected
        case zoomWarning
        case error(String)
        
        var title: String {
            switch self {
            case .doNotDisturbEnabled:
                return "Hush Activated"
            case .doNotDisturbDisabled:
                return "Hush Deactivated"
            case .screenShareDetected:
                return "Screen Sharing Detected"
            case .zoomWarning:
                return "Zoom is Running"
            case .error:
                return "Hush Error"
            }
        }
        
        var message: String {
            switch self {
            case .doNotDisturbEnabled:
                return "Do Not Disturb enabled"
            case .doNotDisturbDisabled:
                return "Do Not Disturb disabled"
            case .screenShareDetected:
                return "Do Not Disturb has been enabled"
            case .zoomWarning:
                return "Zoom is running. Do Not Disturb has been enabled."
            case .error(let message):
                return message
            }
        }
    }
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if we're running in test mode
        let isTestMode = CommandLine.arguments.contains("UITestMode")
        
        loadPreferences()
        setupIcons()
        setupStatusBar()
        setupCoreComponents()
        setupMonitoring()
        setupNotificationObservers()
        
        // Show welcome screen on first launch, but not in test mode
        if preferences.isFirstLaunch && !isTestMode {
            showWelcomeScreen()
            preferences.isFirstLaunch = false
            savePreferences()
        } else if isTestMode {
            // In test mode, ensure the welcome screen is shown for UI tests
            showWelcomeScreen()
        }
        
        // Check for Zoom and show warning if necessary
        checkForZoomAndWarn()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up and disable DND if needed
        if isCurrentlyBlocking {
            dndManager.disableAllModes()
        }
        
        // Save statistics and preferences
        saveStatistics()
        savePreferences()
    }
    
    // MARK: - Setup Methods
    
    private func setupIcons() {
        // Create menu bar icons
        iconInactive = NSImage(systemSymbolName: "bell.slash", accessibilityDescription: "Hush - Inactive")
        iconActive = NSImage(systemSymbolName: "bell.slash.fill", accessibilityDescription: "Hush - Active")
        
        // Use template mode for proper dark/light mode rendering
        iconInactive?.isTemplate = true
        iconActive?.isTemplate = true
        
        // Set initial icon
        menuBarIcon = iconInactive
    }
    
    private func setupStatusBar() {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let statusButton = statusBarItem.button {
            statusButton.image = menuBarIcon
            statusButton.toolTip = "Hush: Automatically enables Do Not Disturb when screen sharing"
        }
        
        // Create and set up the menu
        statusMenu = NSMenu()
        
        // Status item (will be updated dynamically)
        statusMenu.addItem(NSMenuItem(title: "Status: Not currently blocking", action: nil, keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        
        // Testing option (single toggle)
        let testItem = NSMenuItem(title: "Toggle Test Mode: Disabled", action: #selector(toggleTestScreenSharing(_:)), keyEquivalent: "t")
        testItem.target = self
        statusMenu.addItem(testItem)
        statusMenu.addItem(NSMenuItem.separator())
        
        // Focus mode submenu
        let focusModeMenu = NSMenu()
        for mode in FocusMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectFocusMode(_:)), keyEquivalent: "")
            item.representedObject = mode
            focusModeMenu.addItem(item)
        }
        
        let focusModeItem = NSMenuItem(title: "Focus Mode", action: nil, keyEquivalent: "")
        focusModeItem.submenu = focusModeMenu
        statusMenu.addItem(focusModeItem)
        
        // Duration submenu
        let durationMenu = NSMenu()
        let durations: [(String, TimeInterval?)] = [
            ("Until Sharing Ends", nil),
            ("15 Minutes", 15 * 60),
            ("30 Minutes", 30 * 60),
            ("1 Hour", 60 * 60),
            ("2 Hours", 2 * 60 * 60)
        ]
        
        for (title, duration) in durations {
            let item = NSMenuItem(title: title, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.representedObject = duration
            durationMenu.addItem(item)
        }
        
        let durationItem = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        statusMenu.addItem(durationItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // Preferences
        statusMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        statusMenu.addItem(NSMenuItem(title: "Statistics", action: #selector(showStatistics), keyEquivalent: "s"))
        statusMenu.addItem(NSMenuItem(title: "About Hush", action: #selector(showAbout), keyEquivalent: ""))
        
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusBarItem.menu = statusMenu
        
        // Update menu items to reflect current preferences
        updateMenuItemStates()
    }
    
    private func setupCoreComponents() {
        // Initialize screen share detector
        screenShareDetector = ScreenShareDetector(autoStart: true)
        
        // Initialize DND manager
        dndManager = DNDManager()
        
        // Set up options based on preferences
        updateFocusOptions()
    }
    
    private func setupMonitoring() {
        // Use a timer to periodically check for screen sharing
        // Adjustable interval based on preferences
        let interval = preferences.detectionIntervalSeconds
        
        detectionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkScreenShareStatus()
        }
        
        // Trigger an initial check
        checkScreenShareStatus()
    }
    
    private func setupNotificationObservers() {
        // Listen for Focus mode state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusModeChange(_:)),
            name: DNDManager.focusModeChangedNotification,
            object: nil
        )
        
        // Listen for Focus mode errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusModeError(_:)),
            name: DNDManager.focusErrorNotification,
            object: nil
        )
    }
    
    // MARK: - Core Functionality
    
    private func checkScreenShareStatus() {
        // Check for Zoom and show warning if needed
        checkForZoomAndWarn()
        
        // Check and log Focus mode status for debugging
        logFocusModeStatus()
        
        // If we're in test mode, don't interfere with the test
        if isInTestMode {
            // Log to console for debugging
            print("Test mode active - skipping real screen share detection")
            return
        }
        
        // First, check specifically for Zoom as it's a common case
        let isZoomRunning = self.isZoomRunning()
        
        // If Zoom detection already handled enabling DND, we can return
        if isZoomRunning && isCurrentlyBlocking {
            print("Zoom is running and blocking is active")
            return
        }
        
        // If no Zoom, check for other screen sharing activities
        let isScreenSharing = screenShareDetector.isScreenSharing()
        
        // Debug output
        print("Screen sharing state: \(isScreenSharing)")
        print("Zoom running: \(isZoomRunning)")
        
        // Update status based on screen sharing state
        if isScreenSharing != lastScreenSharingState {
            lastScreenSharingState = isScreenSharing
            
            if isScreenSharing {
                enableDoNotDisturbForScreenSharing()
            } else {
                disableDoNotDisturbAfterScreenSharing()
            }
        }
        
        // If status shows not blocking but we're screen sharing, fix it
        if (isScreenSharing || isZoomRunning) && !isCurrentlyBlocking {
            // Force update the UI to show blocking
            updateStatusMenuItem(blocking: true)
            updateMenuBarIcon(active: true)
            
            // Re-enable Do Not Disturb
            enableDoNotDisturbForScreenSharing()
        }
    }
    
    private func enableDoNotDisturbForScreenSharing() {
        print("Enabling Do Not Disturb for screen sharing")
        
        // Create options based on preferences
        var options = FocusOptions()
        options.mode = FocusMode(rawValue: preferences.selectedFocusModeRawValue) ?? .standard
        options.duration = preferences.selectedDuration
        
        // First approach: Use DNDManager
        dndManager.enableDoNotDisturb(options: options)
        
        // Second approach: Direct terminal command as fallback (most reliable)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Check if DND is actually enabled by checking the preference directly
            let isDNDEnabled = self.checkIsDNDEnabled()
            
            if !isDNDEnabled {
                print("DNDManager approach failed, trying direct terminal commands")
                self.enableDNDWithTerminalCommands()
            }
        }
        
        isCurrentlyBlocking = true
        updateStatusMenuItem(blocking: true)
        updateMenuBarIcon(active: true)
        
        // Show notification if enabled
        if preferences.showNotifications {
            sendNotification(for: .doNotDisturbEnabled)
        }
        
        // Update statistics
        statistics.lastActivated = Date()
        
        saveStatistics()
    }
    
    // New helper method to directly enable DND with terminal commands
    private func enableDNDWithTerminalCommands() -> Bool {
        let commands = [
            // Most direct approach - widely compatible
            "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean true",
            
            // NCPrefs approach (newer macOS)
            "defaults write com.apple.ncprefs dnd_prefs -dict userPref 1",
            
            // Recent macOS Focus control
            "defaults write com.apple.controlcenter Focus -int 2",
            
            // Restart NotificationCenter to apply changes
            "killall NotificationCenter &>/dev/null || true",
            "killall ControlCenter &>/dev/null || true"
        ]
        
        var success = false
        
        for command in commands {
            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", command]
            
            do {
                try task.run()
                task.waitUntilExit()
                print("Successfully executed: \(command)")
                success = true
            } catch {
                print("Failed to execute command: \(command)")
            }
        }
        
        return success && checkIsDNDEnabled()
    }
    
    // Helper method to check if DND is actually enabled
    private func checkIsDNDEnabled() -> Bool {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "defaults -currentHost read com.apple.notificationcenterui doNotDisturb 2>/dev/null || echo '0'"]
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("1")
            }
        } catch {
            print("Error checking DND status: \(error)")
        }
        
        return false
    }
    
    private func disableDoNotDisturbAfterScreenSharing() {
        // Only disable if it was automatically enabled (not if manually enabled)
        if isCurrentlyBlocking && !preferences.keepEnabledAfterSharing {
            print("Disabling Do Not Disturb after screen sharing")
            
            // First approach: Use DNDManager
            dndManager.disableAllModes()
            
            // Second approach: Direct terminal command as fallback (most reliable)
            disableDNDWithTerminalCommands()
            
            isCurrentlyBlocking = false
            updateStatusMenuItem(blocking: false)
            updateMenuBarIcon(active: false)
            
            // Show notification if enabled
            if preferences.showNotifications {
                sendNotification(for: .doNotDisturbDisabled)
            }
            
            // Update statistics
            statistics.lastDeactivated = Date()
            
            if let lastActivated = statistics.lastActivated {
                let duration = Date().timeIntervalSince(lastActivated)
                statistics.totalActiveTime += duration
                statistics.sessionCount += 1
            }
        }
        
        saveStatistics()
    }
    
    // New helper method to directly disable DND with terminal commands
    private func disableDNDWithTerminalCommands() {
        let commands = [
            // Most direct approach - widely compatible
            "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean false",
            
            // NCPrefs approach (newer macOS)
            "defaults write com.apple.ncprefs dnd_prefs -dict userPref 0",
            
            // AssertionServices approach
            "defaults write com.apple.AssertionServices assertionEnabled -bool false",
            
            // Restart NotificationCenter to apply changes
            "killall NotificationCenter &>/dev/null || true"
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
            }
        }
    }
    
    private func updateStatusMenuItem(blocking: Bool) {
        if let statusItem = statusMenu.item(at: 0) {
            statusItem.title = blocking ? "Status: Blocking notifications" : "Status: Not currently blocking"
        }
    }
    
    private func updateMenuBarIcon(active: Bool) {
        if let statusButton = statusBarItem.button {
            statusButton.image = active ? iconActive : iconInactive
        }
    }
    
    private func updateMenuItemStates() {
        // Update the Focus mode menu items
        if let focusModeItem = statusMenu.item(withTitle: "Focus Mode"),
           let submenu = focusModeItem.submenu {
            for item in submenu.items {
                if let mode = item.representedObject as? FocusMode {
                    let currentMode = FocusMode(rawValue: preferences.selectedFocusModeRawValue) ?? .standard
                    item.state = mode == currentMode ? .on : .off
                }
            }
        }
        
        // Update the Duration menu items
        if let durationItem = statusMenu.item(withTitle: "Duration"),
           let submenu = durationItem.submenu {
            for item in submenu.items {
                if let duration = item.representedObject as? TimeInterval? {
                    item.state = duration == preferences.selectedDuration ? .on : .off
                }
            }
        }
    }
    
    private func updateFocusOptions() {
        // This method is called when preferences change that affect focus options
        // Nothing needed here as we create new options each time we enable DND
    }
    
    // MARK: - Preferences Management
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "HushPreferences") {
            do {
                preferences = try JSONDecoder().decode(Preferences.self, from: data)
            } catch {
                print("Failed to load preferences: \(error)")
                // Use default preferences
            }
        }
    }
    
    private func savePreferences() {
        do {
            let data = try JSONEncoder().encode(preferences)
            UserDefaults.standard.set(data, forKey: "HushPreferences")
        } catch {
            print("Failed to save preferences: \(error)")
        }
    }
    
    // MARK: - Statistics Management
    
    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: "HushStatistics") {
            do {
                statistics = try JSONDecoder().decode(Statistics.self, from: data)
            } catch {
                print("Failed to load statistics: \(error)")
                // Use default statistics
            }
        }
    }
    
    private func saveStatistics() {
        do {
            let data = try JSONEncoder().encode(statistics)
            UserDefaults.standard.set(data, forKey: "HushStatistics")
        } catch {
            print("Failed to save statistics: \(error)")
        }
    }
    
    // MARK: - Launch at Login Management
    
    private func setLaunchAtLogin(enabled: Bool) {
        // Wrap all code in a do-catch to prevent crashes
        do {
            if #available(macOS 13.0, *) {
                // Use the new ServiceManagement API for macOS 13+
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } else {
                // Use the legacy method for older macOS versions
                let identifier = Bundle.main.bundleIdentifier ?? "com.example.HushLauncher"
                let launcherAppId = identifier as CFString
                
                // Just use SMLoginItemSetEnabled without checking for errors
                SMLoginItemSetEnabled(launcherAppId, enabled)
            }
            
            // Update the preference
            preferences.launchAtLogin = enabled
            savePreferences()
            
            print("Launch at login \(enabled ? "enabled" : "disabled") successfully")
        } catch {
            // Log the error but don't crash
            print("Failed to configure launch at login: \(error.localizedDescription)")
            
            // Still update the preference to avoid further attempts
            preferences.launchAtLogin = false
            savePreferences()
            
            // Only show notification if error notifications are enabled
            if preferences.showErrorNotifications {
                showNotification(
                    title: "Launch at Login Error",
                    message: "Could not configure automatic startup: \(error.localizedDescription)"
                )
            }
        }
    }
    
    // MARK: - Notification Methods
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        if preferences.enableNotificationSound {
            content.sound = UNNotificationSound.default
        }
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // Helper method to send notifications, used by various parts of the app
    private func sendNotification(for type: NotificationType) {
        showNotification(title: type.title, message: type.message)
    }
    
    // MARK: - Menu Actions
    
    @objc func selectFocusMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? FocusMode {
            preferences.selectedFocusModeRawValue = mode.rawValue
            savePreferences()
            updateMenuItemStates()
            
            // If currently blocking, update the active mode
            if isCurrentlyBlocking {
                var options = FocusOptions()
                options.mode = mode
                options.duration = preferences.selectedDuration
                dndManager.enableDoNotDisturb(options: options)
            }
        }
    }
    
    @objc func selectDuration(_ sender: NSMenuItem) {
        if let duration = sender.representedObject as? TimeInterval? {
            preferences.selectedDuration = duration
            savePreferences()
            updateMenuItemStates()
        }
    }
    
    @objc func handleFocusModeChange(_ notification: Notification) {
        // Handle focus mode changes
        if let userInfo = notification.userInfo,
           let success = userInfo["success"] as? Bool,
           success {
            // Update UI based on the successful mode change
            if let active = userInfo["active"] as? Bool {
                updateMenuBarIcon(active: active)
            }
        }
    }
    
    @objc func handleFocusModeError(_ notification: Notification) {
        // Handle focus mode errors
        if let userInfo = notification.userInfo,
           let errorMessage = userInfo["error"] as? String {
            // Show error notification
            if preferences.showErrorNotifications {
                showNotification(title: "Hush Error", message: errorMessage)
            }
            
            // Log the error
            print("Focus mode error: \(errorMessage)")
        }
    }
    
    @objc func showPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        
        if preferencesWindow == nil {
            // Create and configure the preferences window
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.center()
            preferencesWindow?.title = "Hush Preferences"
            
            // Create the content view
            let preferencesView = NSHostingView(rootView: PreferencesView(preferences: preferences) { [weak self] updatedPrefs in
                self?.preferences = updatedPrefs
                self?.savePreferences()
                self?.updateMenuItemStates()
                self?.updateFocusOptions()
                
                // Update launch at login if changed
                if updatedPrefs.launchAtLogin != self?.preferences.launchAtLogin {
                    self?.setLaunchAtLogin(enabled: updatedPrefs.launchAtLogin)
                }
            })
            
            preferencesWindow?.contentView = preferencesView
            
            // Handle window close
            preferencesWindow?.isReleasedWhenClosed = false
        }
        
        // Show the window
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func showStatistics() {
        NSApp.activate(ignoringOtherApps: true)
        
        if statisticsWindow == nil {
            // Create and configure the statistics window
            statisticsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            statisticsWindow?.center()
            statisticsWindow?.title = "Hush Statistics"
            
            // Create the content view
            let statisticsView = NSHostingView(rootView: StatisticsView(
                statistics: statistics,
                onRefresh: { [weak self] in
                    self?.loadStatistics()  // Reload statistics when the view appears
                }
            ))
            statisticsWindow?.contentView = statisticsView
            
            // Handle window close
            statisticsWindow?.isReleasedWhenClosed = false
        }
        
        // Show the window
        statisticsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func showWelcomeScreen() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Create and configure the welcome window
        let welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        welcomeWindow.center()
        welcomeWindow.title = "Welcome to Hush"
        welcomeWindow.isReleasedWhenClosed = true
        
        // Store weak reference to prevent retain cycles
        weak var weakWindow = welcomeWindow
        
        // Create the content view
        let welcomeView = NSHostingView(rootView: WelcomeView(onComplete: { [weak self] launchAtLogin in
            // Make sure we have a self reference
            guard let self = self else {
                DispatchQueue.main.async {
                    weakWindow?.close()
                }
                return
            }
            
            // Set launch at login preference if selected
            if launchAtLogin {
                // Use a lightweight Task to avoid blocking the UI
                Task {
                    self.setLaunchAtLogin(enabled: true)
                }
            }
            
            // Make sure to mark first launch as completed
            self.preferences.isFirstLaunch = false
            self.savePreferences()
            
            // Close the welcome window safely on the main thread
            DispatchQueue.main.async {
                weakWindow?.close()
            }
            
            print("Welcome screen completed successfully")
        }))
        
        welcomeWindow.contentView = welcomeView
        
        // Show the window
        welcomeWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Create and configure the about window
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.center()
        aboutWindow.title = "About Hush"
        aboutWindow.isReleasedWhenClosed = false
        
        // Create the content
        let aboutView = NSHostingView(rootView: AboutView())
        aboutWindow.contentView = aboutView
        
        // Show the window
        aboutWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
        // Disable DND if we enabled it
        if isCurrentlyBlocking {
            dndManager.disableAllModes()
        }
        
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Debug Methods
    
    @objc func toggleTestScreenSharing(_ sender: NSMenuItem) {
        // Toggle test mode state
        isInTestMode = !isInTestMode
        
        if isInTestMode {
            // Enable test mode - simulate screen sharing started
            lastScreenSharingState = true
            enableDoNotDisturbForScreenSharing()
            sender.title = "Toggle Test Mode: ● Enabled"
            sender.state = .on
            
            // Update app icon
            updateMenuBarIcon(active: true)
            
            // Notify the user
            showNotification(
                title: "Test Mode",
                message: "Test mode enabled - simulating screen sharing"
            )
            
            // Log
            print("Test mode enabled - simulating screen sharing")
        } else {
            // Disable test mode - simulate screen sharing ended
            lastScreenSharingState = false
            disableDoNotDisturbAfterScreenSharing()
            sender.title = "Toggle Test Mode: Disabled"
            sender.state = .off
            
            // Update app icon
            updateMenuBarIcon(active: false)
            
            // Notify the user
            showNotification(
                title: "Test Mode",
                message: "Test mode disabled - normal operation resumed"
            )
            
            // Log
            print("Test mode disabled - normal operation resumed")
        }
    }
    
    // MARK: - Zoom Compatibility
    
    /// Checks if Zoom is running and shows a warning if needed
    private func checkForZoomAndWarn() {
        // Only check for Zoom at the interval specified in preferences
        let now = Date()
        if let lastCheck = lastZoomCheckTime,
           now.timeIntervalSince(lastCheck) < preferences.zoomDetectionIntervalSeconds {
            // Skip if we checked recently
            return
        }
        
        // Update the last check time
        lastZoomCheckTime = now
        
        // Run a full Zoom detection
        if isZoomRunning() {
            // If we're not already blocking and not in test mode, enable DND automatically
            if !isCurrentlyBlocking && !isInTestMode {
                print("Zoom detected - automatically enabling DND")
                enableDoNotDisturbForZoom()
            }
        }
    }
    
    /// Special method to enable DND specifically for Zoom
    private func enableDoNotDisturbForZoom() {
        print("Enabling Do Not Disturb for Zoom")
        
        // Create options based on preferences
        var options = FocusOptions()
        options.mode = FocusMode(rawValue: preferences.selectedFocusModeRawValue) ?? .standard
        options.duration = preferences.selectedDuration
        
        // First try direct terminal commands for maximum reliability
        let terminalSuccess = enableDNDWithTerminalCommands()
        print("Terminal command approach for Zoom: \(terminalSuccess ? "succeeded" : "failed")")
        
        // Use DNDManager as backup approach
        dndManager.enableDoNotDisturb(options: options)
        
        // Set state flags
        isCurrentlyBlocking = true
        updateStatusMenuItem(blocking: true)
        updateMenuBarIcon(active: true)
        
        // No notification - we want this to be silent
        
        // Update statistics
        statistics.lastActivated = Date()
        statistics.zoomActivations += 1
        
        saveStatistics()
        
        // Verify DND is actually enabled and retry if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Check if DND is actually enabled
            let isDNDEnabled = self.checkIsDNDEnabled()
            
            if !isDNDEnabled {
                print("DND not successfully enabled for Zoom - retrying with direct terminal commands")
                
                // Try one more time with direct terminal commands
                let success = self.enableDNDWithTerminalCommands()
                print("DND retry with terminal commands: \(success ? "succeeded" : "failed")")
            }
        }
    }
    
    /// Detects if Zoom is currently running
    private func isZoomRunning() -> Bool {
        let zoomBundleID = "us.zoom.xos"
        
        // First check: Is the Zoom app running?
        let isZoomAppRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == zoomBundleID
        }
        
        if !isZoomAppRunning {
            return false
        }
        
        // Second check: Look for specific Zoom windows that indicate an active meeting
        let foundZoomMeeting = checkForZoomMeetingWindows()
        
        print("Zoom detection: App running=\(isZoomAppRunning), Meeting windows=\(foundZoomMeeting)")
        
        // Return true if Zoom is running AND we either found meeting windows
        // OR we just want to trigger on Zoom running regardless of meeting windows
        return isZoomAppRunning
    }
    
    /// Helper method to look for specific Zoom windows that indicate an active meeting
    private func checkForZoomMeetingWindows() -> Bool {
        // Get all on-screen windows
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        // Look for windows with names that indicate an active Zoom meeting
        let zoomMeetingPatterns = [
            "Zoom Meeting",
            "Meeting",
            "is sharing screen",
            "screen sharing",
            "Share Screen",
            "Participants",
            "Chat",
            "Zoom"
        ]
        
        for window in windowList {
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               ownerName.lowercased().contains("zoom") {
                
                if let name = window[kCGWindowName as String] as? String {
                    for pattern in zoomMeetingPatterns {
                        if name.lowercased().contains(pattern.lowercased()) {
                            print("Found Zoom meeting window: \(name)")
                            return true
                        }
                    }
                    
                    // Debug: log all Zoom window names to help with pattern matching
                    print("Zoom window found: \(name)")
                }
            }
        }
        
        return false
    }
    
    /// Shows a warning dialog about Zoom's screen sharing settings
    private func showZoomWarning() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Create a custom window for better styling - make it narrower (400px instead of 460px)
        let warningWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        warningWindow.center()
        warningWindow.isReleasedWhenClosed = true
        warningWindow.titlebarAppearsTransparent = true
        warningWindow.titleVisibility = .hidden
        warningWindow.backgroundColor = NSColor(calibratedWhite: 0.9, alpha: 0.95)
        
        // Create main content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 320))
        warningWindow.contentView = contentView
        
        // Add app icon - center it in the narrower window
        let iconView = NSImageView(frame: NSRect(x: 165, y: 240, width: 70, height: 70))
        iconView.image = NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "hand.raised.slash", accessibilityDescription: "Hush")
        contentView.addSubview(iconView)
        
        // Add title
        let titleLabel = NSTextField(labelWithString: "Zoom Warning")
        titleLabel.frame = NSRect(x: 20, y: 210, width: 360, height: 30)
        titleLabel.alignment = .center
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        contentView.addSubview(titleLabel)
        
        // Add message
        let messageLabel = NSTextField(wrappingLabelWithString: "To prevent a conflict with Hush, open Zoom's \"Screen Share\" preferences category and disable the \"silence notifications when sharing desktop\" option.")
        messageLabel.frame = NSRect(x: 50, y: 100, width: 300, height: 100)
        messageLabel.alignment = .center
        contentView.addSubview(messageLabel)
        
        // Add buttons side by side with minimal spacing
        let buttonWidth = 145
        let buttonHeight = 32
        let buttonSpacing = 10
        let buttonsY = 20
        let totalButtonWidth = (buttonWidth * 2) + buttonSpacing
        let startX = (400 - totalButtonWidth) / 2
        
        let openZoomButton = NSButton(title: "Open Zoom", target: self, action: #selector(openZoomFromWarning(_:)))
        openZoomButton.frame = NSRect(x: startX, y: buttonsY, width: buttonWidth, height: buttonHeight)
        openZoomButton.bezelStyle = .rounded
        contentView.addSubview(openZoomButton)
        
        let okButton = NSButton(title: "OK", target: self, action: #selector(closeZoomWarning(_:)))
        okButton.frame = NSRect(x: startX + buttonWidth + buttonSpacing, y: buttonsY, width: buttonWidth, height: buttonHeight)
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)
        
        // Add checkbox
        let checkbox = NSButton(checkboxWithTitle: "Don't ask again", target: self, action: #selector(toggleDontAskAgain(_:)))
        checkbox.frame = NSRect(x: 50, y: 60, width: 300, height: 20)
        checkbox.alignment = .center
        contentView.addSubview(checkbox)
        
        // Store window and checkbox for access in action methods
        self.zoomWarningWindow = warningWindow
        self.zoomWarningCheckbox = checkbox
        
        // Show the window
        warningWindow.makeKeyAndOrderFront(nil)
    }
    
    // Temporary storage for zoom warning UI elements
    private var zoomWarningWindow: NSWindow?
    private var zoomWarningCheckbox: NSButton?
    
    @objc private func closeZoomWarning(_ sender: NSButton) {
        // Check if "Don't ask again" was checked
        let dontAskAgain = zoomWarningCheckbox?.state == .on
        
        // Only save preferences if user checked the checkbox
        if dontAskAgain {
            preferences.hasShownZoomWarning = true
            savePreferences()
        } else {
            // If they didn't check it, we'll show the warning again later
            preferences.hasShownZoomWarning = false
            savePreferences()
        }
        
        // Close the window
        zoomWarningWindow?.close()
        zoomWarningWindow = nil
        zoomWarningCheckbox = nil
    }
    
    @objc private func openZoomFromWarning(_ sender: NSButton) {
        // Check if "Don't ask again" was checked
        let dontAskAgain = zoomWarningCheckbox?.state == .on
        
        // Only save preferences if user checked the checkbox
        if dontAskAgain {
            preferences.hasShownZoomWarning = true
            savePreferences()
        } else {
            // If they didn't check it, we'll show the warning again later
            preferences.hasShownZoomWarning = false
            savePreferences()
        }
        
        // Launch Zoom
        NSWorkspace.shared.open(URL(string: "zoommtg://")!)
        
        // Close the window
        zoomWarningWindow?.close()
        zoomWarningWindow = nil
        zoomWarningCheckbox = nil
    }
    
    @objc private func toggleDontAskAgain(_ sender: NSButton) {
        // This is just a checkbox event handler, no action needed here
    }
    
    // Diagnostic function to check and log Focus mode status
    private func logFocusModeStatus() {
        // Check if the system thinks Focus mode is active
        let blockingState = isCurrentlyBlocking
        let dndActive = dndManager.isAnyModeActive()
        
        print("Focus Mode Diagnostics:")
        print("- App thinks Focus is active: \(blockingState)")
        print("- DNDManager reports Focus active: \(dndActive)")
        
        // Check status via System Events AppleScript to verify UI state
        let script = """
        tell application "System Events"
            try
                -- Try to get Focus menu bar status
                if exists menu bar item "Focus" of menu bar 1 then
                    set focusMenu to menu bar item "Focus" of menu bar 1
                    set focusMenuTitle to title of focusMenu
                    return "Focus menu: " & focusMenuTitle
                else
                    return "No Focus menu found"
                end if
            end try
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        if let result = appleScript?.executeAndReturnError(&error) {
            print("- System Focus status: \(result.stringValue ?? "unknown")")
        } else if let error = error {
            print("- Error checking system Focus: \(error)")
        }
        
        // Log inconsistencies to help debugging
        if blockingState != dndActive {
            print("⚠️ Inconsistency detected: App state doesn't match DNDManager state")
            
            // Try to fix the inconsistency
            if !blockingState && dndActive {
                // DNDManager thinks Focus is active but app doesn't - update app state
                print("Fixing inconsistency: Updating app state to match DNDManager")
                isCurrentlyBlocking = true
                updateStatusMenuItem(blocking: true)
                updateMenuBarIcon(active: true)
            } else if blockingState && !dndActive {
                // App thinks Focus is active but DNDManager doesn't - re-enable
                print("Fixing inconsistency: Re-enabling Focus mode")
                enableDoNotDisturbForScreenSharing()
            }
        }
    }
    
    private func shouldShowZoomWarning() -> Bool {
        // Don't show if user chose to never show warnings
        if preferences.neverShowZoomWarning {
            return false
        }
        
        // Only show warning once every 30 minutes to avoid spamming
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        let showAgain = preferences.lastZoomWarningTime == nil || 
                       preferences.lastZoomWarningTime! < thirtyMinutesAgo
        
        return showAgain
    }
    
    private func showZoomWarningWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Zoom is Running"
        
        let contentView = NSHostingView(rootView: ZoomWarningView(
            preferences: preferences,
            onPreferenceChange: { [weak self] updatedPrefs in
                // Update preferences when changed by the view
                self?.preferences = updatedPrefs
                self?.savePreferences()
            },
            onClose: { [weak self, weak window] in
                window?.close()
                self?.zoomWarningWindow = nil
            },
            onEnableDND: { [weak self, weak window] in
                self?.toggleDNDState()
                window?.close()
                self?.zoomWarningWindow = nil
            }
        ))
        
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        
        window.makeKeyAndOrderFront(nil)
        
        // Record the time we showed the warning
        preferences.lastZoomWarningTime = Date()
        savePreferences()
        
        zoomWarningWindow = window
    }
    
    @objc private func toggleDNDState() {
        if isCurrentlyBlocking {
            if dndManager.isAnyModeActive() {
                dndManager.disableAllModes()
                disableDNDWithTerminalCommands()
            }
            
            isCurrentlyBlocking = false
            updateStatusMenuItem(blocking: false)
            updateMenuBarIcon(active: false)
            
            // Show notification if enabled
            if preferences.showNotifications {
                sendNotification(for: .doNotDisturbDisabled)
            }
            
            // Update statistics
            statistics.lastDeactivated = Date()
            statistics.manualDisables += 1
            
            if let lastActivated = statistics.lastActivated {
                let duration = Date().timeIntervalSince(lastActivated)
                statistics.totalActiveTime += duration
                statistics.sessionCount += 1
            }
        } else {
            // Create options based on preferences
            var options = FocusOptions()
            options.mode = FocusMode(rawValue: preferences.selectedFocusModeRawValue) ?? .standard
            options.duration = preferences.selectedDuration
            
            // Enable Do Not Disturb
            dndManager.enableDoNotDisturb(options: options)
            
            // Also try direct terminal approach for reliability
            enableDNDWithTerminalCommands()
            
            isCurrentlyBlocking = true
            updateStatusMenuItem(blocking: true)
            updateMenuBarIcon(active: true)
            
            // Show notification if enabled
            if preferences.showNotifications {
                sendNotification(for: .doNotDisturbEnabled)
            }
            
            // Update statistics
            statistics.lastActivated = Date()
            statistics.manualActivations += 1
        }
        
        saveStatistics()
    }
    
    private func handleUncaughtException(exception: NSException) {
        let errorMessage = "Uncaught exception: \(exception.name). \(exception.reason ?? "No reason provided")"
        print("Error: \(errorMessage)")
        
        // Log the error to console
        NSLog("Hush Error: %@", errorMessage)
        
        // Show a notification to the user
        sendNotification(for: .error(errorMessage))
        
        // Attempt to save any unsaved state to prevent data loss
        savePreferences()
        saveStatistics()
    }
    
    // MARK: - Lifecycle
    
    deinit {
        // Clean up resources
        preferencesWindow?.close()
        preferencesWindow = nil
        
        statisticsWindow?.close()
        statisticsWindow = nil
    }
} 
