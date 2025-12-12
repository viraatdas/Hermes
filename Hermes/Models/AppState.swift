import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isRecording = false
    @Published var currentMeeting: Meeting?
    @Published var upcomingMeetings: [Meeting] = [] {
        didSet {
            print("📊 AppState.upcomingMeetings updated: \(upcomingMeetings.count) meetings")
            // Force UI update
            objectWillChange.send()
        }
    }
    @Published var recordedMeetings: [RecordedMeeting] = []
    @Published var isAuthenticated = false
    @Published var isScreenSharing = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var recordingTimer: Timer?
    
    private init() {
        loadRecordedMeetings()
    }
    
    func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }
    
    func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func loadRecordedMeetings() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let hermesURL = documentsURL.appendingPathComponent("Hermes")
        let metadataURL = hermesURL.appendingPathComponent("metadata.json")
        
        if let data = try? Data(contentsOf: metadataURL),
           let meetings = try? JSONDecoder().decode([RecordedMeeting].self, from: data) {
            recordedMeetings = meetings.sorted { $0.date > $1.date }
        }
    }
    
    func saveRecordedMeetings() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let hermesURL = documentsURL.appendingPathComponent("Hermes")
        
        try? fileManager.createDirectory(at: hermesURL, withIntermediateDirectories: true)
        
        let metadataURL = hermesURL.appendingPathComponent("metadata.json")
        if let data = try? JSONEncoder().encode(recordedMeetings) {
            try? data.write(to: metadataURL)
        }
    }
    
    func addRecordedMeeting(_ meeting: RecordedMeeting) {
        recordedMeetings.insert(meeting, at: 0)
        saveRecordedMeetings()
    }
}

