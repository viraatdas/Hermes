import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject private var calendarService = GoogleCalendarService.shared
    @ObservedObject private var anthropicService = AnthropicService.shared

    @State private var anthropicAPIKey = ""
    @State private var statusMessage: String?
    @State private var isConnectingCalendar = false
    @State private var isTestingAnthropic = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            VStack(spacing: 18) {
                calendarStep
                anthropicStep
            }
            .padding(20)

            Divider()
            footer
        }
        .frame(width: 560)
        .onAppear {
            if !anthropicService.hasAPIKey {
                _ = anthropicService.importLocalCredentials()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set Up Hermes")
                .font(.system(size: 24, weight: .bold))

            Text("Connect your calendar with OAuth and use the Anthropic credentials stored on this laptop for meeting Q&A and notes.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    private var calendarStep: some View {
        setupRow(
            icon: "calendar.badge.checkmark",
            title: "Google Calendar",
            status: calendarService.isAuthenticated ? "Connected" : "Connect with Google OAuth",
            isComplete: calendarService.isAuthenticated
        ) {
            if calendarService.isAuthenticated {
                Button("Disconnect") {
                    calendarService.signOut()
                }
                .foregroundColor(.red)
            } else {
                Button(isConnectingCalendar ? "Connecting..." : "Connect Calendar") {
                    isConnectingCalendar = true
                    Task {
                        do {
                            try await calendarService.authenticate()
                            statusMessage = "Calendar connected"
                            OnboardingWindowPresenter.closeIfComplete()
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                        isConnectingCalendar = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnectingCalendar)
            }
        }
    }

    private var anthropicStep: some View {
        setupRow(
            icon: "sparkles",
            title: "AI Provider",
            status: anthropicService.credentialSourceDescription,
            isComplete: anthropicService.hasAPIKey
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Picker("", selection: $anthropicService.activeProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .frame(width: 230)

                if !anthropicService.hasAPIKey {
                    HStack {
                        SecureField(anthropicService.activeProvider.placeholder, text: $anthropicAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 230)

                        Button("Save") {
                            anthropicService.saveCredential(anthropicAPIKey, for: anthropicService.activeProvider)
                            anthropicAPIKey = ""
                            statusMessage = "\(anthropicService.activeProvider.displayName) saved"
                            OnboardingWindowPresenter.closeIfComplete()
                        }
                        .disabled(anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                HStack {
                    Button("Import File…") {
                        importCredentialFile()
                    }
                    .disabled(anthropicService.hasAPIKey)

                    Button("Use Env Vars") {
                        if anthropicService.importLocalCredentials() {
                            statusMessage = "Credential imported"
                            OnboardingWindowPresenter.closeIfComplete()
                        } else {
                            statusMessage = anthropicService.lastError
                        }
                    }
                    .disabled(anthropicService.hasAPIKey)

                    Button(isTestingAnthropic ? "Testing..." : "Test") {
                        testAnthropic()
                    }
                    .disabled(!anthropicService.hasAPIKey || isTestingAnthropic)
                }
            }
        }
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
                statusMessage = "\(anthropicService.activeProvider.displayName) imported"
                OnboardingWindowPresenter.closeIfComplete()
            } else {
                statusMessage = anthropicService.lastError
            }
        }
    }

    private var footer: some View {
        HStack {
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Later") {
                OnboardingWindowPresenter.close()
            }

            Button("Done") {
                OnboardingWindowPresenter.close()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!calendarService.isAuthenticated || !anthropicService.hasAPIKey)
        }
        .padding(16)
    }

    private func setupRow<Actions: View>(
        icon: String,
        title: String,
        status: String,
        isComplete: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isComplete ? .green : Color(hex: "D4AF37"))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(isComplete ? .green : .orange)
                        .frame(width: 7, height: 7)
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            actions()
        }
        .padding(14)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func testAnthropic() {
        isTestingAnthropic = true
        Task {
            do {
                statusMessage = try await anthropicService.testConnection()
            } catch {
                statusMessage = error.localizedDescription
            }
            isTestingAnthropic = false
        }
    }
}

@MainActor
enum OnboardingWindowPresenter {
    private static var window: NSWindow?

    static func openIfNeeded() {
        guard !GoogleCalendarService.shared.isAuthenticated || !AnthropicService.shared.hasAPIKey else {
            return
        }
        open()
    }

    static func open() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: OnboardingView())
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Set Up Hermes"
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func closeIfComplete() {
        if GoogleCalendarService.shared.isAuthenticated && AnthropicService.shared.hasAPIKey {
            close()
        }
    }

    static func close() {
        window?.close()
    }
}

#Preview {
    OnboardingView()
}
