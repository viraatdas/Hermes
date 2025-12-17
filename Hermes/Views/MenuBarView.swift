import SwiftUI

struct MenuBarView: View {
    // Observe AppState to trigger redraws when meetings change
    @ObservedObject private var appState = AppState.shared
    @ObservedObject var calendarService = GoogleCalendarService.shared
    @ObservedObject var recorder = AudioRecorder.shared
    @Environment(\.openWindow) private var openWindow
    
    @State private var isRefreshing = false
    
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
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                    }
                    .padding(.top, 12)
                    
                    // Always show events if we have them
                    let meetings = appState.upcomingMeetings
                    if meetings.count > 0 {
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
                            Text("Click to load your calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Button("Load Events") {
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
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 380, height: calendarService.isAuthenticated ? 480 : 320)
    }
    
    private func refreshCalendar() {
        print("🔄 Refresh button clicked")
        isRefreshing = true
        
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
