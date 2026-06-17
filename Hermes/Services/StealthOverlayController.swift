import AppKit
import SwiftUI
import Combine

/// Backing state for the stealth overlay. Survives show/hide so captured
/// follow-ups and the last answer persist across toggles.
@MainActor
final class StealthOverlayModel: ObservableObject {
    static let shared = StealthOverlayModel()

    @Published var draft = ""
    @Published var askText = ""
    @Published var answer = ""
    @Published var isAsking = false
    @Published var captured: [ScratchItem] = []

    struct ScratchItem: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let time: String
        let pushedToNotes: Bool
    }

    private init() {}

    var hasActiveMeeting: Bool { MeetingNotesStore.shared.hasActiveSession }
    var hasCredential: Bool { AnthropicService.shared.hasAPIKey }

    func capture() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let pushed = MeetingNotesStore.shared.appendFollowUp(text)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        captured.insert(ScratchItem(text: text, time: formatter.string(from: Date()), pushedToNotes: pushed), at: 0)
        draft = ""
    }

    func ask() {
        let question = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAsking else { return }

        isAsking = true
        answer = ""
        let context = MeetingNotesStore.shared.overlayContext
        Task {
            do {
                answer = try await AnthropicService.shared.quickAsk(question, context: context)
            } catch {
                answer = error.localizedDescription
            }
            isAsking = false
        }
    }

    func clearAnswer() {
        answer = ""
        askText = ""
    }
}

/// A panel that is hidden from screen sharing / screen recording and floats
/// above everything without stealing focus from the meeting window.
final class StealthPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class StealthOverlayController {
    static let shared = StealthOverlayController()

    private var panel: StealthPanel?
    private(set) var isVisible = false

    private init() {}

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func makePanel() -> StealthPanel {
        let width: CGFloat = 360
        let height: CGFloat = 440

        let panel = StealthPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        // The core trick: exclude this window from any screen capture / sharing.
        panel.sharingType = .none

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.setFrameAutosaveName("HermesStealthOverlay")

        panel.contentView = NSHostingView(rootView: StealthOverlayView())

        if let screen = NSScreen.main?.visibleFrame {
            let origin = NSPoint(x: screen.maxX - width - 28, y: screen.maxY - height - 28)
            panel.setFrameOrigin(origin)
        }

        return panel
    }
}
