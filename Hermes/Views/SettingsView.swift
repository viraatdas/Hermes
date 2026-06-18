import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var calendarService = GoogleCalendarService.shared
    @ObservedObject var anthropicService = AnthropicService.shared
    
    @AppStorage("notificationMinutesBefore") private var notificationMinutesBefore = 5
    @AppStorage("autoRecordMeetings") private var autoRecordMeetings = true
    @AppStorage("hideWhenScreenSharing") private var hideWhenScreenSharing = true
    @AppStorage("audioQuality") private var audioQuality = "high"

    // Google OAuth credentials (stored locally; used when Info.plist keys are empty)
    @AppStorage("googleOAuthClientId") private var googleOAuthClientId = ""
    @AppStorage("googleOAuthClientSecret") private var googleOAuthClientSecret = ""
    
    @State private var launchAtLogin = false
    @State private var credentialInput = ""
    @State private var anthropicStatus: String?
    @State private var isTestingAnthropic = false
    
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

            aiTab
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 470, height: 380)
        .hiddenFromScreenCapture()
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
                
                Toggle("Hide menu bar icon while screen sharing", isOn: $hideWhenScreenSharing)
                
                Picker("Notification before meeting", selection: $notificationMinutesBefore) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
            }

            Section {
                LabeledContent("Set Up Account", value: "⌃⌥⌘H")
                LabeledContent("Open Calendar", value: "⌃⌥⌘C")
                LabeledContent("Open Notes", value: "⌃⌥⌘N")
                LabeledContent("Start or Stop Recording", value: "⌃⌥⌘R")
                LabeledContent("Toggle Private Overlay", value: "⌃⌥⌘Space")
            } header: {
                Text("Hotkeys")
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

    // MARK: - AI Tab

    private var aiTab: some View {
        Form {
            Section {
                Picker("Provider", selection: $anthropicService.activeProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                HStack {
                    Image(systemName: anthropicService.hasAPIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(anthropicService.hasAPIKey ? .green : .secondary)
                    Text(anthropicService.hasAPIKey
                         ? "\(anthropicService.activeProvider.displayName) configured"
                         : "No credential for \(anthropicService.activeProvider.displayName)")
                    Spacer()
                }

                SecureField(anthropicService.activeProvider.placeholder, text: $credentialInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                HStack {
                    Button("Save") {
                        anthropicService.saveCredential(credentialInput, for: anthropicService.activeProvider)
                        credentialInput = ""
                        anthropicStatus = "Saved \(anthropicService.activeProvider.displayName)"
                    }
                    .disabled(credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(isTestingAnthropic ? "Testing..." : "Test") {
                        isTestingAnthropic = true
                        Task {
                            do {
                                anthropicStatus = try await anthropicService.testConnection()
                            } catch {
                                anthropicStatus = error.localizedDescription
                            }
                            isTestingAnthropic = false
                        }
                    }
                    .disabled(!anthropicService.hasAPIKey || isTestingAnthropic)

                    Spacer()

                    Button("Clear") {
                        anthropicService.clearCredential(for: anthropicService.activeProvider)
                        credentialInput = ""
                        anthropicStatus = "Cleared"
                    }
                    .foregroundColor(.red)
                    .disabled(!anthropicService.hasAPIKey)
                }

                if let anthropicStatus {
                    Text(anthropicStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("AI Credential")
            } footer: {
                Text("Claude Code uses your subscription OAuth token (Bearer auth). Codex/OpenAI uses an API key. Anthropic uses a standard API key.")
                    .font(.caption)
            }

            Section {
                Button("Import from Claude Code / Codex file…") {
                    importCredentialFile()
                }

                Button("Use Environment Variables") {
                    if anthropicService.importLocalCredentials() {
                        anthropicStatus = "Imported \(anthropicService.activeProvider.displayName)"
                    } else {
                        anthropicStatus = anthropicService.lastError
                    }
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Pick ~/.claude/.credentials.json or ~/.codex/auth.json to import an existing CLI login. (In the open panel press ⌘⇧G to type the hidden path.)")
                    .font(.caption)
            }

            Section {
                Text("Used for live meeting Q&A, the private overlay copilot, and generating editable notes. Audio and transcripts stay local unless you ask a question or generate notes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func importCredentialFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.message = "Select ~/.claude/.credentials.json or ~/.codex/auth.json"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            if anthropicService.importCredentialFile(at: url) {
                anthropicStatus = "Imported \(anthropicService.activeProvider.displayName)"
            } else {
                anthropicStatus = anthropicService.lastError
            }
        }
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            HermesLogo(size: 80)
            
            Text("Hermes")
                .font(.system(size: 28, weight: .bold, design: .serif))
            
            Text("Meeting notes for the age of agents")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Version 0.2.7")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text("© 2026 Hermes")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

#Preview {
    SettingsView()
}
