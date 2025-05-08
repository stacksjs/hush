import SwiftUI
import Foundation

// MARK: - Views

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Hush").font(.title)
            Text("Version 1.0").font(.caption)
            Text("Mutes notifications when screen sharing")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("© 2024 All rights reserved")
                .font(.caption2)
                .padding(.top, 10)
        }
        .frame(width: 280, height: 180)
        .padding()
    }
}

struct PreferencesView: View {
    @State var preferences: Preferences
    var onSave: (Preferences) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Text("General Settings")) {
                VStack(alignment: .leading) {
                    Toggle("Launch at startup", isOn: $preferences.launchAtLogin)
                    
                    Divider()
                    
                    HStack {
                        Text("Detection interval:")
                        Slider(value: $preferences.detectionIntervalSeconds, in: 0.5...5.0, step: 0.5)
                        Text("\(preferences.detectionIntervalSeconds, specifier: "%.1f")s")
                    }
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Focus Settings")) {
                VStack(alignment: .leading) {
                    Picker("Focus Mode:", selection: $preferences.selectedFocusModeRawValue) {
                        ForEach(FocusMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    
                    Divider()
                    
                    Toggle("Keep enabled after sharing ends", isOn: $preferences.keepEnabledAfterSharing)
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Notifications")) {
                VStack(alignment: .leading) {
                    Toggle("Show notifications", isOn: $preferences.showNotifications)
                    Toggle("Play sound", isOn: $preferences.enableNotificationSound)
                        .disabled(!preferences.showNotifications)
                    Toggle("Show error notifications", isOn: $preferences.showErrorNotifications)
                }
                .padding(10)
            }
            
            HStack {
                Spacer()
                Button("Save") {
                    onSave(preferences)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
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
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "bell.slash.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)
                
                Text("Welcome to Hush")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)
                
                Text("Hush automatically enables Do Not Disturb mode when you're sharing your screen, protecting your privacy from notifications.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Getting Started:")
                    .font(.system(size: 18, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach([
                        "Hush runs in your menu bar, quietly monitoring for screen sharing",
                        "When screen sharing is detected, Do Not Disturb is automatically enabled",
                        "When screen sharing ends, Do Not Disturb is disabled",
                        "Open preferences to customize how Hush works"
                    ], id: \.self) { text in
                        HStack(alignment: .top, spacing: 12) {
                            Text("•")
                                .font(.system(size: 16, weight: .bold))
                            Text(text)
                                .font(.system(size: 16))
                                .lineLimit(nil)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 20)
            
            VStack(spacing: 30) {
                Toggle("Launch Hush when you log in", isOn: $launchAtLogin)
                    .font(.system(size: 16))
                    .padding(.horizontal, 20)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                
                Button(action: {
                    onComplete(launchAtLogin)
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 60)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 30)
            }
        }
        .frame(width: 600, height: 530)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
} 