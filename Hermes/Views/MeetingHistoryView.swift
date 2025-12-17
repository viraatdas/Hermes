import SwiftUI
import AVKit

struct MeetingHistoryView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedMeeting: RecordedMeeting?
    @State private var searchText = ""
    
    var filteredMeetings: [RecordedMeeting] {
        if searchText.isEmpty {
            return appState.recordedMeetings
        }
        return appState.recordedMeetings.filter { meeting in
            meeting.title.localizedCaseInsensitiveContains(searchText) ||
            (meeting.transcript?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Meeting List
            List(filteredMeetings, selection: $selectedMeeting) { meeting in
                MeetingListItem(meeting: meeting)
                    .tag(meeting)
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search meetings")
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        appState.loadRecordedMeetings()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }
            }
        } detail: {
            // Detail - Meeting View
            if let meeting = selectedMeeting {
                MeetingDetailView(meeting: meeting)
            } else {
                EmptyStateView()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            appState.loadRecordedMeetings()
            if selectedMeeting == nil {
                selectedMeeting = appState.recordedMeetings.first
            }
        }
        .onChange(of: appState.recordedMeetings) { _, newValue in
            // If nothing is selected, auto-select newest so the update is obvious.
            if selectedMeeting == nil {
                selectedMeeting = newValue.first
            }
        }
    }
}

// MARK: - Meeting List Item

struct MeetingListItem: View {
    let meeting: RecordedMeeting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meeting.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            
            HStack(spacing: 12) {
                Label(meeting.formattedDate, systemImage: "calendar")
                Label(meeting.formattedDuration, systemImage: "clock")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            
            if meeting.transcript != nil {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                    Text("Transcript available")
                }
                .font(.system(size: 10))
                .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Meeting Detail View

struct MeetingDetailView: View {
    let meeting: RecordedMeeting
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showingTranscript = true
    @State private var isExporting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                Divider()
                
                // Audio Player
                audioPlayerSection
                
                Divider()
                
                // Transcript
                if let transcript = meeting.transcript {
                    transcriptSection(transcript: transcript)
                } else {
                    transcriptionPendingSection
                }
            }
            .padding(24)
        }
        .navigationTitle(meeting.title)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: exportAudio) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)
                
                Button(action: openInFinder) {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.title)
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                Label(meeting.formattedDate, systemImage: "calendar")
                Label(meeting.formattedDuration, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Audio Player Section
    
    private var audioPlayerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.linearGradient(
                            colors: [Color(hex: "FFB347"), Color(hex: "FF6B35")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.audioURL?.lastPathComponent ?? "Recording")
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(meeting.formattedDuration)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Transcript Section
    
    private func transcriptSection(transcript: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                
                Spacer()
                
                Button(action: copyTranscript) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            
            Text(transcript)
                .font(.system(size: 13))
                .lineSpacing(6)
                .textSelection(.enabled)
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
        }
    }
    
    private var transcriptionPendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)
            
            HStack {
                Image(systemName: "text.badge.xmark")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No transcript available")
                        .font(.system(size: 13, weight: .medium))
                    
                    Text("Transcription may still be in progress or failed.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Transcribe Now") {
                    Task {
                        await transcribeNow()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    
    private func setupPlayer() {
        guard let url = meeting.audioURL else { return }
        player = AVPlayer(url: url)
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func exportAudio() {
        isExporting = true
        
        Task {
            do {
                let exportURL = try await MeetingManager.shared.exportAsMP3(recordedMeeting: meeting)
                
                // Show save panel
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.audio]
                savePanel.nameFieldStringValue = exportURL.lastPathComponent
                
                if savePanel.runModal() == .OK, let destination = savePanel.url {
                    try FileManager.default.copyItem(at: exportURL, to: destination)
                }
            } catch {
                print("Export failed: \(error)")
            }
            
            isExporting = false
        }
    }
    
    private func openInFinder() {
        guard let url = meeting.audioURL else { return }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    private func copyTranscript() {
        guard let transcript = meeting.transcript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
    }
    
    private func transcribeNow() async {
        guard let audioURL = meeting.audioURL else { return }
        
        do {
            let transcriptURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
            _ = try await TranscriptionService.shared.transcribeAndSave(
                audioURL: audioURL,
                outputURL: transcriptURL
            )
            
            // Refresh the meeting data
            AppState.shared.loadRecordedMeetings()
        } catch {
            print("Transcription failed: \(error)")
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select a Recording")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Choose a meeting from the sidebar to view its details and transcript.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }
}

#Preview {
    MeetingHistoryView()
        .environmentObject(AppState.shared)
}

