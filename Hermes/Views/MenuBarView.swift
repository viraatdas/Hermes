import SwiftUI

struct MenuBarView: View {
    // Observe AppState to trigger redraws when meetings change
    @ObservedObject private var appState = AppState.shared
    @ObservedObject var calendarService = GoogleCalendarService.shared
    @ObservedObject var recorder = AudioRecorder.shared
    @Environment(\.openWindow) private var openWindow
    
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date = .distantPast
    
    private var menuHeight: CGFloat {
        var height: CGFloat = calendarService.isAuthenticated ? 480 : 320
        if appState.isRecording {
            height += 100 // Extra space for recording controls
        }
        return height
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HermesLogo(size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hermes")
                        .font(.system(size: 15, weight: .semibold))
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(calendarService.isAuthenticated ? .green : .orange)
                            .frame(width: 6, height: 6)
                        Text(calendarService.isAuthenticated ? "Connected" : "Not connected")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if appState.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.bottom, 12)
            
            // Recording controls - show when recording
            if appState.isRecording {
                RecordingControlsView()
                    .padding(.bottom, 12)
            }
            
            Divider()
            
            // Main content
            if calendarService.isAuthenticated {
                // Calendar events section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("📅 EVENTS (\(appState.upcomingMeetings.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: refreshCalendar) {
                            if isRefreshing || calendarService.isLoadingCalendar {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing || calendarService.isLoadingCalendar)
                    }
                    .padding(.top, 12)
                    
                    // Show loading state or events
                    let meetings = appState.upcomingMeetings
                    if calendarService.isLoadingCalendar && meetings.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading calendar...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if meetings.count > 0 {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(meetings) { meeting in
                                    EventRow(meeting: meeting)
                                }
                            }
                        }
                        .frame(maxHeight: 280)
                    } else {
                        VStack(spacing: 8) {
                            Text("No upcoming events")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Button("Refresh") {
                                refreshCalendar()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "D4AF37"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                }
            } else {
                // Not connected
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "D4AF37"))
                    
                    Text("Connect Google Calendar")
                        .font(.system(size: 13, weight: .medium))
                    
                    Button("Connect") {
                        Task {
                            try? await calendarService.authenticate()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "D4AF37"))
                }
                .padding(.vertical, 30)
            }
            
            Divider()
                .padding(.top, 12)
            
            // Footer actions
            VStack(spacing: 2) {
                // Open Calendar window
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "calendar")
                }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Open Calendar")
                        Spacer()
                        Text("⌘C")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                
                // Test notification button
                Button(action: {
                    Task {
                        await NotificationService.shared.sendTestNotification()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Test Notification")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let fileManager = FileManager.default
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let hermesURL = documentsURL.appendingPathComponent("Hermes/Recordings")
                    try? fileManager.createDirectory(at: hermesURL, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(hermesURL)
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Recordings Folder")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.vertical, 4)
                
                Button(action: {
                    // Dispatch async to allow menu to close first
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit Hermes")
                        Spacer()
                        Text("⌘Q")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 380, height: menuHeight)
        .onAppear {
            // Auto-refresh calendar when menu opens (with 10 second debounce)
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
            if calendarService.isAuthenticated && !isRefreshing && !calendarService.isLoadingCalendar && timeSinceLastRefresh > 10 {
                refreshCalendar()
            }
        }
    }
    
    private func refreshCalendar() {
        print("🔄 Refresh button clicked")
        isRefreshing = true
        lastRefreshTime = Date()
        
        Task { @MainActor in
            do {
                print("🔄 Fetching meetings...")
                let fetched = try await calendarService.fetchUpcomingMeetings()
                print("🔄 Got \(fetched.count) meetings")
                
                // Update AppState (this triggers UI refresh)
                AppState.shared.upcomingMeetings = fetched
                
                // Schedule notifications
                await NotificationService.shared.scheduleNotifications(for: fetched)
                
            } catch {
                print("❌ Failed to refresh: \(error)")
            }
            
            isRefreshing = false
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let meeting: Meeting
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Date/Time
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(meeting.startTime))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "D4AF37"))
                
                Text(formatTime(meeting.startTime))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .frame(width: 70, alignment: .leading)
            
            // Colored bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "D4AF37"))
                .frame(width: 3)
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                if meeting.meetingURL != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 8))
                        Text("Video call")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Join button
            if meeting.meetingURL != nil && isHovered {
                Button("Join") {
                    Task {
                        await MeetingManager.shared.joinAndRecord(meeting: meeting)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Recording Controls

struct RecordingControlsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var recorder = AudioRecorder.shared
    @State private var isStopping = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Recording info
            HStack {
                // Pulsing red dot
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .modifier(PulseEffect())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentMeeting?.title ?? "Recording")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Text(formatDuration(appState.recordingDuration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Stop button
            Button(action: stopRecording) {
                HStack {
                    if isStopping {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "stop.fill")
                    }
                    Text(isStopping ? "Stopping..." : "Stop Recording")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isStopping)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func stopRecording() {
        isStopping = true
        Task {
            await MeetingManager.shared.stopRecording()
            isStopping = false
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Hermes Logo

struct HermesLogo: View {
    var size: CGFloat = 32
    var isRecording: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isRecording 
                            ? [Color(hex: "DC143C"), Color(hex: "8B0000")]
                            : [Color(hex: "D4AF37"), Color(hex: "B8860B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Wings + H
            ZStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.25, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .rotationEffect(.degrees(45))
                    .offset(x: -size * 0.2, y: -size * 0.06)
                
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.25, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .rotationEffect(.degrees(-45))
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: size * 0.2, y: -size * 0.06)
                
                Text("H")
                    .font(.system(size: size * 0.35, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    MenuBarView()
}
