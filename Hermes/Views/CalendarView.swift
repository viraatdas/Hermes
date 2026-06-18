import SwiftUI

struct CalendarView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var calendarService = GoogleCalendarService.shared

    @State private var isRefreshing = false

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)

            if !calendarService.isAuthenticated {
                notConnectedState
            } else if displayDays.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(displayDays.enumerated()), id: \.element.id) { index, day in
                            DayBlock(day: day)
                            if index < displayDays.count - 1 {
                                Divider()
                                    .padding(.leading, 96)
                                    .opacity(0.5)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 480)
        .hiddenFromScreenCapture()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Coming up")
                .font(.system(size: 30, weight: .bold, design: .serif))

            Spacer()

            Button(action: refreshCalendar) {
                if isRefreshing {
                    ProgressView().scaleEffect(0.6).frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(isRefreshing)
            .help("Refresh")
        }
    }

    // MARK: - States

    private var notConnectedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "D4AF37"))
            Text("Connect your calendar")
                .font(.system(size: 16, weight: .semibold))
            Text("See your upcoming meetings and join them with one click.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Connect Google Calendar") {
                Task { try? await calendarService.authenticate() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "D4AF37"))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Nothing on the calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Upcoming events will show up here.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private var displayDays: [DayEvents] {
        var grouped: [Date: [Meeting]] = [:]
        for meeting in appState.upcomingMeetings where meeting.endTime >= Date() {
            let dayStart = calendar.startOfDay(for: meeting.startTime)
            grouped[dayStart, default: []].append(meeting)
        }

        // Always lead with today, even when it has no events.
        let today = calendar.startOfDay(for: Date())
        if grouped[today] == nil {
            grouped[today] = []
        }

        return grouped
            .map { DayEvents(date: $0.key, events: $0.value.sorted { $0.startTime < $1.startTime }) }
            .sorted { $0.date < $1.date }
    }

    private func refreshCalendar() {
        isRefreshing = true
        Task {
            do {
                let meetings = try await calendarService.fetchUpcomingMeetings()
                await MainActor.run { appState.upcomingMeetings = meetings }
                await NotificationService.shared.scheduleNotifications(for: meetings)
            } catch {
                print("Failed to refresh calendar: \(error)")
            }
            await MainActor.run { isRefreshing = false }
        }
    }
}

// MARK: - Day block

private struct DayEvents: Identifiable {
    let date: Date
    let events: [Meeting]
    var id: Date { date }
}

private struct DayBlock: View {
    let day: DayEvents
    private let calendar = Calendar.current

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            dateColumn
                .frame(width: 64, alignment: .leading)

            if day.events.isEmpty {
                Text("No events today")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 14) {
                    ForEach(day.events) { event in
                        EventRowDetail(event: event)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var dateColumn: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(calendar.component(.day, from: day.date))")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(monthString)
                        .font(.system(size: 13, weight: .medium))
                    if calendar.isDateInToday(day.date) {
                        Circle().fill(Color(hex: "D4AF37")).frame(width: 5, height: 5)
                    }
                }
                Text(weekdayString)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var monthString: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: day.date)
    }

    private var weekdayString: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: day.date)
    }
}

// MARK: - Event row

private struct EventRowDetail: View {
    let event: Meeting
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "D4AF37").opacity(0.85))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(timeRange)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if event.meetingURL != nil {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            if event.meetingURL != nil {
                Button(action: {
                    Task { await MeetingManager.shared.joinAndRecord(meeting: event) }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 11))
                        Text("Join")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "D4AF37"))
                .controlSize(.small)
                .opacity(isHovered ? 1 : 0.0)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var timeRange: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return "\(f.string(from: event.startTime)) – \(f.string(from: event.endTime))"
    }
}

#Preview {
    CalendarView()
}
