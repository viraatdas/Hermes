import AppKit
import Carbon
import SwiftUI

enum GlobalHotkeyAction: UInt32 {
    case openSetup = 1
    case openCalendar = 2
    case openNotes = 3
    case toggleRecording = 4
    case toggleOverlay = 5
}

struct GlobalHotkey {
    let action: GlobalHotkeyAction
    let keyCode: UInt32
    let displayShortcut: String

    static let all: [GlobalHotkey] = [
        GlobalHotkey(action: .openSetup, keyCode: UInt32(kVK_ANSI_H), displayShortcut: "⌃⌥⌘H"),
        GlobalHotkey(action: .openCalendar, keyCode: UInt32(kVK_ANSI_C), displayShortcut: "⌃⌥⌘C"),
        GlobalHotkey(action: .openNotes, keyCode: UInt32(kVK_ANSI_N), displayShortcut: "⌃⌥⌘N"),
        GlobalHotkey(action: .toggleRecording, keyCode: UInt32(kVK_ANSI_R), displayShortcut: "⌃⌥⌘R"),
        GlobalHotkey(action: .toggleOverlay, keyCode: UInt32(kVK_Space), displayShortcut: "⌃⌥⌘Space")
    ]
}

final class GlobalHotkeyService {
    static let shared = GlobalHotkeyService()

    private let signature = fourCharCode("Hrms")
    private let modifiers = UInt32(controlKey | optionKey | cmdKey)
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [GlobalHotkeyAction: EventHotKeyRef] = [:]
    private var isRegistered = false

    private init() {}

    func register() {
        guard !isRegistered else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr {
                    GlobalHotkeyService.shared.handleHotkey(id: hotKeyID.id)
                }

                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard installStatus == noErr else {
            print("Failed to install global hotkey handler: \(installStatus)")
            return
        }

        for hotkey in GlobalHotkey.all {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: signature, id: hotkey.action.rawValue)

            let status = RegisterEventHotKey(
                hotkey.keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let hotKeyRef {
                hotKeyRefs[hotkey.action] = hotKeyRef
            } else {
                print("Failed to register global hotkey \(hotkey.displayShortcut): \(status)")
            }
        }

        isRegistered = true
    }

    func unregister() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        isRegistered = false
    }

    private func handleHotkey(id: UInt32) {
        guard let action = GlobalHotkeyAction(rawValue: id) else { return }

        Task { @MainActor in
            HotkeyActionService.perform(action)
        }
    }
}

@MainActor
enum HotkeyActionService {
    static func perform(_ action: GlobalHotkeyAction) {
        switch action {
        case .openSetup:
            OnboardingWindowPresenter.open()
        case .openCalendar:
            AppWindowPresenter.openCalendar()
        case .openNotes:
            MeetingNotesWindowPresenter.open()
        case .toggleRecording:
            toggleRecording()
        case .toggleOverlay:
            StealthOverlayController.shared.toggle()
        }
    }

    private static func toggleRecording() {
        if AppState.shared.isRecording {
            Task {
                await MeetingManager.shared.stopRecording()
            }
            return
        }

        let meeting = Meeting(
            id: UUID().uuidString,
            title: "Manual Recording",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            meetingURL: nil,
            calendarId: nil
        )

        Task {
            await MeetingManager.shared.joinAndRecord(meeting: meeting)
        }
    }
}

@MainActor
enum AppWindowPresenter {
    private static var calendarWindow: NSWindow?

    static func openCalendar() {
        if let calendarWindow {
            show(calendarWindow)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Calendar"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: CalendarView())
        window.center()
        window.isReleasedWhenClosed = false
        calendarWindow = window

        show(window)
    }

    private static func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf16.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
