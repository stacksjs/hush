import SwiftUI

// Import the models
@_exported import struct Hush.Preferences
@_exported import enum Hush.FocusMode
@_exported import struct Hush.Statistics

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
                    Picker("Focus Mode:", selection: $preferences.selectedFocusMode) {
                        ForEach(FocusMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
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
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Hush")
                .font(.title)
                .bold()
            
            Text("Hush automatically enables Do Not Disturb mode when you're sharing your screen, protecting your privacy from notifications.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Getting Started:").font(.headline).padding(.top)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text("•")
                        Text("Hush runs in your menu bar, quietly monitoring for screen sharing")
                    }
                    
                    HStack(alignment: .top) {
                        Text("•")
                        Text("When screen sharing is detected, Do Not Disturb is automatically enabled")
                    }
                    
                    HStack(alignment: .top) {
                        Text("•")
                        Text("When screen sharing ends, Do Not Disturb is disabled")
                    }
                    
                    HStack(alignment: .top) {
                        Text("•")
                        Text("Open preferences to customize how Hush works")
                    }
                }
                .padding(.leading, 10)
            }
            .padding(.horizontal)
            
            Toggle("Launch Hush when you log in", isOn: $launchAtLogin)
                .padding(.horizontal, 40)
                .padding(.top)
            
            Button("Get Started") {
                onComplete(launchAtLogin)
            }
            .padding(.top)
        }
        .frame(width: 480, height: 360)
        .padding()
    }
} 