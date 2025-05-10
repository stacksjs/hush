import SwiftUI
import Foundation

// MARK: - Views

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Use app icon from bundle
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            } else {
                // Fallback to system icon if app icon can't be loaded
                Image(systemName: "bell.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
            }
            
            Text("Hush").font(.title).fontWeight(.medium)
            Text("Version 1.0").font(.caption)
            Text("Mutes notifications when screen sharing.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("© 2025 All rights reserved")
                .font(.caption2)
                .padding(.top, 6)
        }
        .frame(width: 280, height: 200)
        .padding()
    }
}

struct PreferencesView: View {
    @State var preferences: Preferences
    var onSave: (Preferences) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Top spacing to avoid window title bar - match exactly with bottom
            Spacer()
                .frame(height: 80)
            
            // Detection Interval slider with better label
            VStack(alignment: .leading, spacing: 10) {
                Text("Screen sharing check frequency:")
                    .font(.system(size: 15))
                    .padding(.leading, 2)
                
                HStack(spacing: 16) {
                    Slider(value: $preferences.detectionIntervalSeconds, in: 0.5...5.0, step: 0.5)
                    
                    Text("\(preferences.detectionIntervalSeconds, specifier: "%.1f")s")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 45, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            
            // Focus Settings section
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .foregroundColor(.secondary)
                Text("Focus Settings")
                    .font(.headline)
            }
            .padding(.leading, 20)
            .padding(.top, 5)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Focus Mode:")
                            .frame(width: 110, alignment: .leading)
                        
                        Picker("", selection: $preferences.selectedFocusModeRawValue) {
                            ForEach(FocusMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Keep enabled after sharing ends")
                        Spacer()
                        Toggle("", isOn: $preferences.keepEnabledAfterSharing)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
            }
            .padding(.horizontal, 20)
            
            // Notifications section
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .foregroundColor(.secondary)
                Text("Notifications")
                    .font(.headline)
            }
            .padding(.leading, 20)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Show notifications")
                        Spacer()
                        Toggle("", isOn: $preferences.showNotifications)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                    
                    HStack {
                        Text("Play sound")
                            .opacity(preferences.showNotifications ? 1.0 : 0.6)
                        Spacer()
                        Toggle("", isOn: $preferences.enableNotificationSound)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                            .disabled(!preferences.showNotifications)
                            .opacity(preferences.showNotifications ? 1.0 : 0.6)
                    }
                    
                    HStack {
                        Text("Show error notifications")
                        Spacer()
                        Toggle("", isOn: $preferences.showErrorNotifications)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
            }
            .padding(.horizontal, 20)
            
            // Bottom spacing - match exactly with top
            Spacer()
                .frame(height: 20)
            
            // Save button at the bottom - push to bottom edge
            HStack {
                Spacer()
                Button(action: {
                    onSave(preferences)
                }) {
                    Text("Save")
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(DefaultButtonStyle())
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
        .frame(width: 460, height: 500)
    }
}

struct StatisticsView: View {
    let statistics: Statistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                Text("Screen sharing detected:").bold()
                Text("\(statistics.screenSharingActivations) times")
                
                Divider()
                
                Text("Total sessions:").bold()
                Text("\(statistics.sessionCount)")
                
                Divider()
                
                Text("Total active time:").bold()
                Text(statistics.formattedTotalActiveTime)
                
                Divider()
                
                Text("Average session:").bold()
                Text(statistics.formattedAverageSessionDuration)
            }
            
            Group {
                if let lastActive = statistics.lastActivated {
                    Divider()
                    
                    Text("Last activated:").bold()
                    Text(lastActive, style: .date)
                    Text(lastActive, style: .time)
                }
            }
        }
        .frame(width: 300, height: 240)
        .padding()
    }
}

struct WelcomeView: View {
    var onComplete: (Bool) -> Void
    @State private var launchAtLogin = true
    
    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 20) {
                Image(systemName: "bell.slash.circle.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.accentColor)
                    .padding(.top, 24)
                
                Text("Welcome to Hush")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Hush automatically enables Do Not Disturb mode when you're sharing your screen, protecting your privacy from notifications.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 40)
            }
            
            VStack(alignment: .leading, spacing: 24) {
                Text("Getting Started:")
                    .font(.system(size: 20, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 18) {
                    ForEach([
                        "Hush runs in your menu bar, quietly monitoring for screen sharing",
                        "When screen sharing is detected, Do Not Disturb is automatically enabled",
                        "When screen sharing ends, Do Not Disturb is disabled",
                        "Open preferences to customize how Hush works"
                    ], id: \.self) { text in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 18))
                            
                            Text(text)
                                .font(.system(size: 16))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.horizontal, 30)
            
            VStack(spacing: 32) {
                Toggle("Launch Hush when you log in", isOn: $launchAtLogin)
                    .font(.system(size: 16))
                    .padding(.horizontal, 30)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                
                Button(action: {
                    onComplete(launchAtLogin)
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 70)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 36)
            }
        }
        .frame(width: 750, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
} 



