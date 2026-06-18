import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var calendarService = GoogleCalendarService.shared
    @ObservedObject private var anthropicService = AnthropicService.shared

    @State private var anthropicAPIKey = ""
    @State private var statusMessage: String?
    @State private var isConnectingCalendar = false
    @State private var isTestingAnthropic = false

    private let gold = Color(hex: "D4AF37")

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [gold.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                hero

                VStack(spacing: 14) {
                    calendarStep
                    anthropicStep
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 20)
                footer
            }
        }
        .frame(width: 580)
        .frame(minHeight: 600)
        .hiddenFromScreenCapture()
        .onAppear {
            if !anthropicService.hasAPIKey {
                _ = anthropicService.importLocalCredentials()
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            HermesLogo(size: 60)
                .shadow(color: gold.opacity(0.45), radius: 14, y: 4)

            VStack(spacing: 5) {
                Text("Set Up Hermes")
                    .font(.system(size: 27, weight: .bold, design: .serif))

                Text("Two quick steps to private, agent-ready meeting notes.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            progressPills
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .padding(.bottom, 24)
    }

    private var progressPills: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(calendarService.isAuthenticated ? AnyShapeStyle(gold) : AnyShapeStyle(Color.secondary.opacity(0.22)))
                .frame(width: 30, height: 4)
            Capsule()
                .fill(anthropicService.hasAPIKey ? AnyShapeStyle(gold) : AnyShapeStyle(Color.secondary.opacity(0.22)))
                .frame(width: 30, height: 4)
        }
        .padding(.top, 4)
    }

    private var calendarStep: some View {
        stepCard(
            number: 1,
            title: "Google Calendar",
            status: calendarService.isAuthenticated ? "Connected" : "Not connected",
            isComplete: calendarService.isAuthenticated
        ) {
            if calendarService.isAuthenticated {
                HStack {
                    Label("Signed in", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Spacer()
                    Button("Disconnect") { calendarService.signOut() }
                        .foregroundColor(.red)
                        .controlSize(.small)
                }
            } else {
                Button {
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
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(isConnectingCalendar ? "Connecting…" : "Connect Google Calendar")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(gold)
                .controlSize(.large)
                .disabled(isConnectingCalendar)
            }
        }
    }

    private var anthropicStep: some View {
        stepCard(
            number: 2,
            title: "AI Provider",
            status: anthropicService.hasAPIKey ? "Connected" : "Not connected",
            isComplete: anthropicService.hasAPIKey
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ProviderPicker()

                if !anthropicService.hasAPIKey {
                    Text(anthropicService.activeProvider.fieldPrompt)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        SecureField(anthropicService.activeProvider.placeholder, text: $anthropicAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))

                        Button("Save") {
                            anthropicService.saveCredential(anthropicAPIKey, for: anthropicService.activeProvider)
                            anthropicAPIKey = ""
                            statusMessage = "\(anthropicService.activeProvider.displayName) saved"
                            OnboardingWindowPresenter.closeIfComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(gold)
                        .disabled(anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                HStack {
                    Spacer()
                    Button(isTestingAnthropic ? "Testing…" : "Test connection") {
                        testAnthropic()
                    }
                    .controlSize(.small)
                    .disabled(!anthropicService.hasAPIKey || isTestingAnthropic)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let statusMessage {
                    Label(statusMessage, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button("Later") {
                    OnboardingWindowPresenter.close()
                }
                .controlSize(.large)

                Button("Done") {
                    OnboardingWindowPresenter.close()
                }
                .buttonStyle(.borderedProminent)
                .tint(gold)
                .controlSize(.large)
                .disabled(!calendarService.isAuthenticated || !anthropicService.hasAPIKey)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
    }

    private func stepCard<Content: View>(
        number: Int,
        title: String,
        status: String,
        isComplete: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isComplete
                          ? AnyShapeStyle(Color.green)
                          : AnyShapeStyle(LinearGradient(colors: [gold, Color(hex: "B8860B")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .frame(width: 30, height: 30)
                    .shadow(color: (isComplete ? Color.green : gold).opacity(0.4), radius: 5, y: 2)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    statusPill(status, isComplete: isComplete)
                }
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isComplete ? Color.green.opacity(0.35) : gold.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private func statusPill(_ text: String, isComplete: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isComplete ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
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
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Set Up Hermes"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
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
