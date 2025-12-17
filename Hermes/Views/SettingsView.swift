import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var calendarService = GoogleCalendarService.shared
    
    @AppStorage("notificationMinutesBefore") private var notificationMinutesBefore = 5
    @AppStorage("autoRecordMeetings") private var autoRecordMeetings = true
    @AppStorage("hideWhenScreenSharing") private var hideWhenScreenSharing = true
    @AppStorage("audioQuality") private var audioQuality = "high"

    // Google OAuth credentials (stored locally; used when Info.plist keys are empty)
    @AppStorage("googleOAuthClientId") private var googleOAuthClientId = ""
    @AppStorage("googleOAuthClientSecret") private var googleOAuthClientSecret = ""
    
    @State private var launchAtLogin = false
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            calendarTab
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            
            recordingTab
                .tabItem {
                    Label("Recording", systemImage: "waveform")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
        .onAppear {
            launchAtLogin = LaunchAtLoginService.shared.isEnabled
        }
    }
    
    // MARK: - General Tab
    
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginService.shared.isEnabled = newValue
                    }
                
                Toggle("Hide when screen sharing", isOn: $hideWhenScreenSharing)
                
                Picker("Notification before meeting", selection: $notificationMinutesBefore) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Calendar Tab
    
    private var calendarTab: some View {
        Form {
            Section {
                if calendarService.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Google Calendar")
                        Spacer()
                        Button("Disconnect") {
                            calendarService.signOut()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                        Text("Not connected")
                        Spacer()
                        Button("Connect") {
                            Task {
                                try? await calendarService.authenticate()
                            }
                        }
                        .tint(Color(hex: "D4AF37"))
                    }
                }
            } header: {
                Text("Google Calendar")
            }

            Section {
                TextField("Client ID", text: $googleOAuthClientId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                SecureField("Client Secret", text: $googleOAuthClientSecret)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                Text("Required to connect. These are stored locally on your Mac. For distributed builds, credentials are injected during release.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Button("Clear") {
                        googleOAuthClientId = ""
                        googleOAuthClientSecret = ""
                        calendarService.signOut()
                    }
                    .foregroundColor(.red)

                    Spacer()
                }
            } header: {
                Text("OAuth Credentials")
            }
            
            Section {
                Toggle("Auto-record meetings with video links", isOn: $autoRecordMeetings)
                
                Text("When enabled, clicking a meeting notification will automatically open the meeting and start recording.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Automation")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Recording Tab
    
    private var recordingTab: some View {
        Form {
            Section {
                Picker("Audio Quality", selection: $audioQuality) {
                    Text("Standard (64 kbps)").tag("standard")
                    Text("High (128 kbps)").tag("high")
                    Text("Very High (256 kbps)").tag("veryhigh")
                }
            } header: {
                Text("Quality")
            }
            
            Section {
                HStack {
                    Text("Storage Location")
                    Spacer()
                    Text("~/Documents/Hermes")
                        .foregroundColor(.secondary)
                }
                
                Button("Open Recordings Folder") {
                    let fileManager = FileManager.default
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let hermesURL = documentsURL.appendingPathComponent("Hermes/Recordings")
                    
                    try? fileManager.createDirectory(at: hermesURL, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(hermesURL)
                }
            } header: {
                Text("Storage")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            HermesLogo(size: 80)
            
            Text("Hermes")
                .font(.system(size: 28, weight: .bold, design: .serif))
            
            Text("Discrete Meeting Recorder")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("© 2024 Hermes")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

#Preview {
    SettingsView()
}
