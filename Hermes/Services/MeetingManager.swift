import Foundation
import AppKit

@MainActor
class MeetingManager: ObservableObject {
    static let shared = MeetingManager()
    
    @Published var currentRecording: ActiveRecording?
    
    private init() {}
    
    struct ActiveRecording {
        let meeting: Meeting
        let audioURL: URL
        let startTime: Date
    }
    
    func joinAndRecord(meetingId: String) async {
        // Find the meeting
        guard let meeting = AppState.shared.upcomingMeetings.first(where: { $0.id == meetingId }) else {
            print("Meeting not found: \(meetingId)")
            return
        }
        
        await joinAndRecord(meeting: meeting)
    }
    
    func joinAndRecord(meeting: Meeting) async {
        // Open the meeting URL
        var didOpenMeetingURL = false
        if let urlString = meeting.meetingURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            didOpenMeetingURL = true
        }
        
        // Wait a moment for the meeting app to open (not needed for manual recordings)
        if didOpenMeetingURL {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        // Start recording
        do {
            let audioURL = try await AudioRecorder.shared.startRecording(meetingTitle: meeting.title)
            
            currentRecording = ActiveRecording(
                meeting: meeting,
                audioURL: audioURL,
                startTime: Date()
            )
            
            AppState.shared.isRecording = true
            AppState.shared.currentMeeting = meeting
            AppState.shared.startRecordingTimer()
            
            // Start screen share detection
            ScreenShareDetector.shared.startMonitoring()
            
            print("Started recording: \(meeting.title)")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() async {
        guard let recording = currentRecording else { return }
        
        do {
            guard let audioURL = try await AudioRecorder.shared.stopRecording() else {
                return
            }
            
            let duration = Date().timeIntervalSince(recording.startTime)
            
            // Stop screen share detection
            ScreenShareDetector.shared.stopMonitoring()
            
            AppState.shared.isRecording = false
            AppState.shared.stopRecordingTimer()
            AppState.shared.currentMeeting = nil
            
            // Create recorded meeting entry
            let recordedMeeting = RecordedMeeting(
                id: UUID().uuidString,
                title: recording.meeting.title,
                date: recording.startTime,
                duration: duration,
                audioFilePath: audioURL.path,
                transcriptFilePath: nil,
                transcript: nil
            )
            
            // Save the recording metadata
            AppState.shared.addRecordedMeeting(recordedMeeting)
            
            currentRecording = nil
            
            print("Stopped recording: \(recording.meeting.title), duration: \(duration)")
            
            // Start transcription in background
            Task {
                await transcribeRecording(recordedMeeting: recordedMeeting, audioURL: audioURL)
            }
            
        } catch {
            print("Failed to stop recording: \(error)")
        }
    }
    
    private func transcribeRecording(recordedMeeting: RecordedMeeting, audioURL: URL) async {
        do {
            let transcriptURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
            
            let transcript = try await TranscriptionService.shared.transcribeAndSave(
                audioURL: audioURL,
                outputURL: transcriptURL
            )
            
            // Update the recorded meeting with transcript
            var updatedMeeting = recordedMeeting
            updatedMeeting.transcriptFilePath = transcriptURL.path
            updatedMeeting.transcript = transcript
            
            // Update in app state
            if let index = AppState.shared.recordedMeetings.firstIndex(where: { $0.id == recordedMeeting.id }) {
                AppState.shared.recordedMeetings[index] = updatedMeeting
                AppState.shared.saveRecordedMeetings()
            }
            
            print("Transcription completed for: \(recordedMeeting.title)")
        } catch {
            print("Transcription failed: \(error)")
        }
    }
    
    func exportAsMP3(recordedMeeting: RecordedMeeting) async throws -> URL {
        guard let audioURL = recordedMeeting.audioURL else {
            throw ExportError.noAudioFile
        }
        
        let mp3URL = audioURL.deletingPathExtension().appendingPathExtension("mp3")
        
        // Use AVAssetExportSession to convert to MP3
        // Note: macOS doesn't natively support MP3 encoding, so we'll use M4A
        // For true MP3, you'd need LAME encoder or similar
        
        // For now, just copy the M4A file
        // In production, you'd want to use ffmpeg or similar for MP3 conversion
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: mp3URL.path) {
            try fileManager.removeItem(at: mp3URL)
        }
        
        // Since we're already recording in M4A (which is widely compatible),
        // we can provide that as the export format
        // True MP3 would require additional libraries
        
        try fileManager.copyItem(at: audioURL, to: mp3URL)
        
        return mp3URL
    }
}

enum ExportError: Error, LocalizedError {
    case noAudioFile
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .noAudioFile: return "No audio file found"
        case .exportFailed: return "Export failed"
        }
    }
}





