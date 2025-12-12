import SwiftUI

struct CalendarView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var calendarService = GoogleCalendarService.shared
    
    @State private var isRefreshing = false
    @State private var selectedDate = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        HSplitView {
            // Left side - Mini calendar + controls
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Calendar")
                            .font(.title.bold())
                        Text("\(appState.upcomingMeetings.count) upcoming events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: refreshCalendar) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshing)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Month view
                miniCalendar
                
                Spacer()
                
                // Connection status
                if !calendarService.isAuthenticated {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("Not connected")
                            .font(.caption)
                        Button("Connect Google Calendar") {
                            Task {
                                try? await calendarService.authenticate()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "D4AF37"))
                    }
                    .padding()
                }
            }
            .frame(width: 280)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right side - Events list
            VStack(spacing: 0) {
                // Date header
                HStack {
                    Text(selectedDateTitle)
                        .font(.title2.bold())
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Events for selected date and beyond
                if appState.upcomingMeetings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No upcoming events")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Your Google Calendar events will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(sortedGroupedEvents, id: \.date) { item in
                                Section {
                                    ForEach(item.events) { event in
                                        VStack(spacing: 0) {
                                            EventDetailRow(event: event)
                                            Divider()
                                                .padding(.leading, 60)
                                        }
                                    }
                                } header: {
                                    daySectionHeader(for: item.date)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
    
    // MARK: - Mini Calendar
    
    private var miniCalendar: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Text(monthYearString)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            let days = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvents: hasEvents(on: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Text("")
                            .frame(height: 28)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private struct DayEvents: Identifiable {
        let date: Date
        let events: [Meeting]
        var id: Date { date }
    }
    
    private var sortedGroupedEvents: [DayEvents] {
        var grouped: [Date: [Meeting]] = [:]
        for meeting in appState.upcomingMeetings {
            let dayStart = calendar.startOfDay(for: meeting.startTime)
            if grouped[dayStart] == nil {
                grouped[dayStart] = []
            }
            grouped[dayStart]?.append(meeting)
        }
        return grouped.map { DayEvents(date: $0.key, events: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private func daySectionHeader(for date: Date) -> some View {
        HStack {
            if calendar.isDateInToday(date) {
                Text("Today")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(hex: "D4AF37"))
            } else if calendar.isDateInTomorrow(date) {
                Text("Tomorrow")
                    .font(.subheadline.bold())
            } else {
                Text(formatDayHeader(date))
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func formatDayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func generateDaysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func hasEvents(on date: Date) -> Bool {
        appState.upcomingMeetings.contains { meeting in
            calendar.isDate(meeting.startTime, inSameDayAs: date)
        }
    }
    
    private func refreshCalendar() {
        isRefreshing = true
        Task {
            do {
                let meetings = try await calendarService.fetchUpcomingMeetings()
                await MainActor.run {
                    appState.upcomingMeetings = meetings
                }
                await NotificationService.shared.scheduleNotifications(for: meetings)
            } catch {
                print("Failed to refresh: \(error)")
            }
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color(hex: "D4AF37"))
            } else if isToday {
                Circle()
                    .stroke(Color(hex: "D4AF37"), lineWidth: 1.5)
            }
            
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? Color(hex: "D4AF37") : .primary))
                
                if hasEvents && !isSelected {
                    Circle()
                        .fill(Color(hex: "D4AF37"))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Event Detail Row

struct EventDetailRow: View {
    let event: Meeting
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(event.startTime))
                    .font(.system(size: 13, weight: .medium))
                Text(formatTime(event.endTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 55, alignment: .trailing)
            
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "D4AF37"))
                .frame(width: 4)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                
                if event.meetingURL != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text("Video meeting")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Join button
            if event.meetingURL != nil {
                Button(action: {
                    Task {
                        await MeetingManager.shared.joinAndRecord(meeting: event)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Join & Record")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "D4AF37"))
                .opacity(isHovered ? 1 : 0.7)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarView()
}

