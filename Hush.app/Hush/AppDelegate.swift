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
    
    // Preferences
    var preferences = Preferences()
    var preferencesWindow: NSWindow?
    
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
        // Check for Zoom periodically
        checkForZoomAndWarn()
        
        // If we're in test mode, don't interfere with the test
        if isInTestMode {
            // Log to console for debugging
            print("Test mode active - skipping real screen share detection")
            return
        }
        
        // Determine if screen sharing is active
        let isScreenSharing = screenShareDetector.isScreenSharing()
        
        // Specifically check if Zoom is screen sharing
        let isZoomRunning = self.isZoomRunning()
        
        // Debug output - remove in production
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
        if isScreenSharing && !isCurrentlyBlocking {
            // Force update the UI to show blocking
            updateStatusMenuItem(blocking: true)
            updateMenuBarIcon(active: true)
            
            // Re-enable Do Not Disturb
            enableDoNotDisturbForScreenSharing()
        }
    }
    
    private func enableDoNotDisturbForScreenSharing() {
        // Create options based on preferences
        var options = FocusOptions()
        options.mode = FocusMode(rawValue: preferences.selectedFocusModeRawValue) ?? .standard
        options.duration = preferences.selectedDuration
        
        // Enable Do Not Disturb with the configured options
        dndManager.enableDoNotDisturb(options: options)
        
        // Update UI state
        isCurrentlyBlocking = true
        updateStatusMenuItem(blocking: true)
        updateMenuBarIcon(active: true)
        
        // Show notification if enabled
        if preferences.showNotifications {
            showNotification(
                title: "Hush Activated",
                message: "Do Not Disturb enabled while screen sharing"
            )
        }
        
        // Update statistics
        statistics.screenSharingActivations += 1
        statistics.lastActivated = Date()
        saveStatistics()
    }
    
    private func disableDoNotDisturbAfterScreenSharing() {
        // Only disable if it was automatically enabled (not if manually enabled)
        if isCurrentlyBlocking && !preferences.keepEnabledAfterSharing {
            dndManager.disableDoNotDisturb(mode: FocusMode(rawValue: preferences.selectedFocusModeRawValue) ?? .standard)
            
            // Update UI state
            isCurrentlyBlocking = false
            updateStatusMenuItem(blocking: false)
            updateMenuBarIcon(active: false)
            
            // Show notification if enabled
            if preferences.showNotifications {
                showNotification(
                    title: "Hush Deactivated",
                    message: "Do Not Disturb disabled"
                )
            }
            
            // Update statistics
            statistics.lastDeactivated = Date()
            
            if let lastActivated = statistics.lastActivated {
                let duration = Date().timeIntervalSince(lastActivated)
                statistics.totalActiveTime += duration
                statistics.sessionCount += 1
            }
            
            saveStatistics()
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
        
        // Create and configure the statistics window
        let statisticsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        statisticsWindow.center()
        statisticsWindow.title = "Hush Statistics"
        
        // Create the content view
        let statisticsView = NSHostingView(rootView: StatisticsView(statistics: statistics))
        statisticsWindow.contentView = statisticsView
        
        // Show the window
        statisticsWindow.makeKeyAndOrderFront(nil)
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
        if isZoomRunning() && !preferences.hasShownZoomWarning {
            showZoomWarning()
        }
    }
    
    /// Detects if Zoom is currently running
    private func isZoomRunning() -> Bool {
        let zoomBundleID = "us.zoom.xos"
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == zoomBundleID
        }
    }
    
    /// Shows a warning dialog about Zoom's screen sharing settings
    private func showZoomWarning() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Create a custom window for better styling
        let warningWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
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
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 320))
        warningWindow.contentView = contentView
        
        // Add app icon
        let iconView = NSImageView(frame: NSRect(x: 180, y: 240, width: 100, height: 60))
        iconView.image = NSImage(named: "AppIcon")
        contentView.addSubview(iconView)
        
        // Add title
        let titleLabel = NSTextField(labelWithString: "Zoom Warning")
        titleLabel.frame = NSRect(x: 20, y: 210, width: 420, height: 30)
        titleLabel.alignment = .center
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        contentView.addSubview(titleLabel)
        
        // Add message
        let messageLabel = NSTextField(wrappingLabelWithString: "To prevent a conflict with Hush, open Zoom's \"Screen Share\" preferences category and disable the \"silence notifications when sharing desktop\" option.\n\nIf you skip this, Zoom will stupidly reverse the changes Hush makes when screensharing starts. We can't all be great developers.")
        messageLabel.frame = NSRect(x: 20, y: 100, width: 420, height: 100)
        messageLabel.alignment = .center
        contentView.addSubview(messageLabel)
        
        // Add buttons
        let okButton = NSButton(title: "OK", target: self, action: #selector(closeZoomWarning(_:)))
        okButton.frame = NSRect(x: 245, y: 20, width: 195, height: 32)
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)
        
        let openZoomButton = NSButton(title: "Open Zoom", target: self, action: #selector(openZoomFromWarning(_:)))
        openZoomButton.frame = NSRect(x: 20, y: 20, width: 195, height: 32)
        openZoomButton.bezelStyle = .rounded
        contentView.addSubview(openZoomButton)
        
        // Add checkbox
        let checkbox = NSButton(checkboxWithTitle: "Don't ask again", target: self, action: #selector(toggleDontAskAgain(_:)))
        checkbox.frame = NSRect(x: 20, y: 60, width: 420, height: 20)
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
        if let checkbox = zoomWarningCheckbox, checkbox.state == .on {
            preferences.hasShownZoomWarning = true
            savePreferences()
        }
        
        // Close the window
        zoomWarningWindow?.close()
        zoomWarningWindow = nil
        zoomWarningCheckbox = nil
    }
    
    @objc private func openZoomFromWarning(_ sender: NSButton) {
        // Launch Zoom
        NSWorkspace.shared.open(URL(string: "zoommtg://")!)
        
        // Check if "Don't ask again" was checked
        if let checkbox = zoomWarningCheckbox, checkbox.state == .on {
            preferences.hasShownZoomWarning = true
            savePreferences()
        }
        
        // Close the window
        zoomWarningWindow?.close()
        zoomWarningWindow = nil
        zoomWarningCheckbox = nil
    }
    
    @objc private func toggleDontAskAgain(_ sender: NSButton) {
        // This is just a checkbox event handler, no action needed here
    }
} 
