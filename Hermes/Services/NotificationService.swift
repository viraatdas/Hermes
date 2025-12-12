import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private var scheduledMeetingIds: Set<String> = []
    
    private init() {}
    
    // Schedule notifications for all upcoming meetings
    func scheduleNotifications(for meetings: [Meeting]) async {
        let center = UNUserNotificationCenter.current()
        
        // Check permission
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            print("⚠️ Notifications not authorized")
            return
        }
        
        // Remove old notifications
        let currentMeetingIds = Set(meetings.map { $0.id })
        let toRemove = scheduledMeetingIds.subtracting(currentMeetingIds)
        center.removePendingNotificationRequests(withIdentifiers: Array(toRemove))
        scheduledMeetingIds.subtract(toRemove)
        
        for meeting in meetings {
            // Skip if already scheduled
            guard !scheduledMeetingIds.contains(meeting.id) else {
                continue
            }
            
            // Only notify for meetings with video links (Google Meet, Zoom, Teams, etc.)
            guard meeting.meetingURL != nil else {
                continue
            }
            
            // Schedule notification 5 minutes before
            let notificationTime = meeting.startTime.addingTimeInterval(-5 * 60)
            
            if notificationTime > Date() {
                // Future notification
                await scheduleNotification(for: meeting, at: notificationTime)
            } else if meeting.timeUntilStart > 0 {
                // Meeting is starting soon (within 5 min), show immediate notification
                await showImmediateNotification(for: meeting)
            }
        }
        
        print("📬 Scheduled notifications for \(scheduledMeetingIds.count) meetings")
    }
    
    private func scheduleNotification(for meeting: Meeting, at date: Date) async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "⚡ Meeting Starting Soon"
        content.body = "\(meeting.title)\nStarts in 5 minutes"
        content.sound = .default
        content.categoryIdentifier = "MEETING_REMINDER"
        content.userInfo = [
            "meetingId": meeting.id,
            "meetingTitle": meeting.title,
            "meetingURL": meeting.meetingURL ?? "",
            "action": "join_record"
        ]
        
        // Add action buttons
        content.interruptionLevel = .timeSensitive
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: meeting.id, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            scheduledMeetingIds.insert(meeting.id)
            print("📬 Scheduled: \(meeting.title) at \(date)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }
    
    private func showImmediateNotification(for meeting: Meeting) async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "⚡ Meeting Starting Now!"
        content.body = "\(meeting.title)\nClick to join and record"
        content.sound = .default
        content.categoryIdentifier = "MEETING_REMINDER"
        content.userInfo = [
            "meetingId": meeting.id,
            "meetingTitle": meeting.title,
            "meetingURL": meeting.meetingURL ?? "",
            "action": "join_record"
        ]
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "immediate-\(meeting.id)", content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            scheduledMeetingIds.insert(meeting.id)
            print("📬 Immediate notification for: \(meeting.title)")
        } catch {
            print("❌ Failed to show notification: \(error)")
        }
    }
    
    // Test notification - shows immediately
    func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        
        // Request permission if needed
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                print("❌ Notification permission denied")
                return
            }
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⚡ Test: Meeting Starting!"
        content.body = "This is a test notification.\nClick to join and record."
        content.sound = .default
        content.categoryIdentifier = "MEETING_REMINDER"
        content.userInfo = [
            "meetingId": "test-123",
            "meetingTitle": "Test Meeting",
            "meetingURL": "https://meet.google.com/test",
            "action": "join_record"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            print("📬 Test notification scheduled!")
        } catch {
            print("❌ Failed to send test notification: \(error)")
        }
    }
    
    func cancelNotification(for meetingId: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [meetingId, "immediate-\(meetingId)"])
        scheduledMeetingIds.remove(meetingId)
    }
    
    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        scheduledMeetingIds.removeAll()
    }
}
