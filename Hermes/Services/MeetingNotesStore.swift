import AppKit
import Foundation

@MainActor
class MeetingNotesStore: ObservableObject {
    static let shared = MeetingNotesStore()

    @Published private(set) var activeTitle: String?
    @Published private(set) var activeAudioURL: URL?
    @Published private(set) var activeNotesURL: URL?
    @Published var notesMarkdown = ""
    @Published var question = ""
    @Published var answer = ""
    @Published var isAsking = false
    @Published var isGenerating = false
    @Published var statusMessage: String?
    @Published var finalTranscript = ""

    private var activeRecordedMeetingId: String?

    private init() {}

    var hasActiveSession: Bool {
        activeTitle != nil
    }

    func startSession(meeting: Meeting, audioURL: URL) {
        activeTitle = meeting.title
        activeAudioURL = audioURL
        activeNotesURL = notesURL(for: audioURL)
        activeRecordedMeetingId = nil
        finalTranscript = ""

        if let existing = activeNotesURL.flatMap({ try? String(contentsOf: $0, encoding: .utf8) }) {
            notesMarkdown = existing
        } else {
            notesMarkdown = initialNotes(title: meeting.title, date: Date())
            saveActiveNotes()
        }

        answer = ""
        question = ""
        statusMessage = "Recording notes"
        LiveTranscriptionService.shared.reset()
        Task {
            await LiveTranscriptionService.shared.start()
        }
    }

    func finishSession(recordedMeeting: RecordedMeeting) -> RecordedMeeting {
        activeRecordedMeetingId = recordedMeeting.id
        activeAudioURL = recordedMeeting.audioURL
        saveActiveNotes()
        LiveTranscriptionService.shared.stop()

        var updated = recordedMeeting
        updated.notesFilePath = activeNotesURL?.path
        updated.notesMarkdown = notesMarkdown
        statusMessage = "Meeting ended"
        return updated
    }

    func updateFinalTranscript(_ transcript: String, for meetingId: String) {
        guard activeRecordedMeetingId == meetingId else { return }
        finalTranscript = transcript
    }

    func clearSession() {
        activeTitle = nil
        activeAudioURL = nil
        activeNotesURL = nil
        notesMarkdown = ""
        question = ""
        answer = ""
        finalTranscript = ""
        activeRecordedMeetingId = nil
        statusMessage = nil
        LiveTranscriptionService.shared.stop()
    }

    func updateNotes(_ value: String) {
        notesMarkdown = value
        saveActiveNotes()

        if let activeRecordedMeetingId,
           let index = AppState.shared.recordedMeetings.firstIndex(where: { $0.id == activeRecordedMeetingId }) {
            AppState.shared.recordedMeetings[index].notesFilePath = activeNotesURL?.path
            AppState.shared.recordedMeetings[index].notesMarkdown = value
            AppState.shared.saveRecordedMeetings()
        }
    }

    func load(meeting: RecordedMeeting) -> String {
        if let path = meeting.notesFilePath,
           let text = try? String(contentsOfFile: path, encoding: .utf8) {
            return text
        }
        if let notes = meeting.notesMarkdown {
            return notes
        }
        return initialNotes(title: meeting.title, date: meeting.date)
    }

    func save(notes: String, for meeting: RecordedMeeting) -> URL? {
        let url = meeting.notesURL ?? meeting.audioURL.map(notesURL(for:))
        guard let url else { return nil }

        do {
            try notes.write(to: url, atomically: true, encoding: .utf8)
            if let index = AppState.shared.recordedMeetings.firstIndex(where: { $0.id == meeting.id }) {
                AppState.shared.recordedMeetings[index].notesFilePath = url.path
                AppState.shared.recordedMeetings[index].notesMarkdown = notes
                AppState.shared.saveRecordedMeetings()
            }
            return url
        } catch {
            statusMessage = error.localizedDescription
            return nil
        }
    }

    func askQuestion() async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty, let title = activeTitle else { return }

        isAsking = true
        defer { isAsking = false }

        do {
            answer = try await AnthropicService.shared.answerQuestion(
                question: trimmedQuestion,
                title: title,
                notes: notesMarkdown,
                transcript: transcriptForAI
            )
            statusMessage = nil
        } catch {
            answer = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    func generateNotes() async {
        guard let title = activeTitle else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let generated = try await AnthropicService.shared.generateNotes(
                title: title,
                currentNotes: notesMarkdown,
                transcript: transcriptForAI
            )
            updateNotes(generated)
            statusMessage = "Notes updated"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func shareActiveNotes() {
        saveActiveNotes()
        var items: [Any] = []
        if let activeNotesURL { items.append(activeNotesURL) }
        if let activeAudioURL { items.append(activeAudioURL) }
        ShareService.share(items: items)
    }

    func share(meeting: RecordedMeeting, notes: String) {
        var items: [Any] = []
        if let notesURL = save(notes: notes, for: meeting) {
            items.append(notesURL)
        }
        if let audioURL = meeting.audioURL {
            items.append(audioURL)
        }
        ShareService.share(items: items)
    }

    private func saveActiveNotes() {
        guard let activeNotesURL else { return }
        do {
            try notesMarkdown.write(to: activeNotesURL, atomically: true, encoding: .utf8)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private var transcriptForAI: String {
        finalTranscript.isEmpty ? LiveTranscriptionService.shared.currentTranscript : finalTranscript
    }

    private func notesURL(for audioURL: URL) -> URL {
        audioURL.deletingPathExtension().appendingPathExtension("notes.md")
    }

    private func initialNotes(title: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short

        return """
        # \(title)

        **Date:** \(formatter.string(from: date))

        ## Summary

        ## Action Items

        ## Decisions

        ## Open Questions

        ## Raw Notes

        """
    }
}

enum ShareService {
    private static var currentPicker: NSSharingServicePicker?

    @MainActor
    static func share(items: [Any]) {
        guard !items.isEmpty else { return }
        guard let contentView = NSApp.keyWindow?.contentView ?? NSApp.mainWindow?.contentView else {
            return
        }

        let picker = NSSharingServicePicker(items: items)
        currentPicker = picker
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
    }
}
