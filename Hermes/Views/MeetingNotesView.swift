import AppKit
import SwiftUI

struct MeetingNotesView: View {
    @ObservedObject private var notes = MeetingNotesStore.shared
    @ObservedObject private var liveTranscript = LiveTranscriptionService.shared
    @ObservedObject private var anthropic = AnthropicService.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if notes.hasActiveSession {
                HSplitView {
                    notesEditor
                        .frame(minWidth: 360)

                    sidePanel
                        .frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
                }
            } else {
                emptyState
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "D4AF37"))

            VStack(alignment: .leading, spacing: 2) {
                Text(notes.activeTitle ?? "Meeting Notes")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    statusDot(color: liveTranscript.isRunning ? .green : .secondary)
                    Text(liveTranscript.isRunning ? "Live transcript running" : "Live transcript stopped")
                    if let status = notes.statusMessage {
                        Text(status)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await notes.generateNotes()
                }
            }) {
                Label(notes.isGenerating ? "Generating" : "Generate Notes", systemImage: "sparkles")
            }
            .disabled(notes.isGenerating || !anthropic.hasAPIKey)

            Button(action: notes.shareActiveNotes) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .padding(14)
    }

    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            TextEditor(text: Binding(
                get: { notes.notesMarkdown },
                set: { notes.updateNotes($0) }
            ))
            .font(.system(size: 13, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color.primary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ask")
                    .font(.headline)

                TextField("Ask about the conversation so far", text: $notes.question)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await notes.askQuestion()
                        }
                    }

                Button(action: {
                    Task {
                        await notes.askQuestion()
                    }
                }) {
                    Label(notes.isAsking ? "Asking" : "Ask", systemImage: "arrow.up.circle.fill")
                }
                .disabled(notes.isAsking || !anthropic.hasAPIKey || notes.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !anthropic.hasAPIKey {
                    Text("Add an Anthropic API key in Settings to use Q&A and AI notes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !notes.answer.isEmpty {
                    Text(notes.answer)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Live Transcript")
                    .font(.headline)

                ScrollView {
                    Text(displayTranscript)
                        .font(.system(size: 12))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .background(Color.primary.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let error = liveTranscript.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Active Meeting")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start recording to open live notes, transcript Q&A, and sharing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }

    private var displayTranscript: String {
        if !notes.finalTranscript.isEmpty {
            return notes.finalTranscript
        }
        if !liveTranscript.currentTranscript.isEmpty {
            return liveTranscript.currentTranscript
        }
        return liveTranscript.isRunning ? "Listening..." : "Transcript will appear here."
    }
}

#Preview {
    MeetingNotesView()
}

@MainActor
enum MeetingNotesWindowPresenter {
    private static var window: NSWindow?

    static func open() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: MeetingNotesView())
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Meeting Notes"
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false
        newWindow.setFrameAutosaveName("MeetingNotesWindow")

        if let screenFrame = NSScreen.main?.visibleFrame {
            let width = min(screenFrame.width * 0.42, 900)
            let height = min(screenFrame.height * 0.84, 760)
            let origin = NSPoint(
                x: screenFrame.maxX - width - 24,
                y: screenFrame.maxY - height - 24
            )
            newWindow.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        }

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
