import SwiftUI
import UserNotifications

@main
struct HermesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
        
        Window("Meeting History", id: "history") {
            MeetingHistoryView()
        }
        
        Window("Calendar", id: "calendar") {
            CalendarView()
        }
        .defaultSize(width: 800, height: 550)
    }
}

struct MenuBarIcon: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: appState.isRecording ? "record.circle.fill" : "livephoto")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appState.isRecording ? .red : Color(red: 0.83, green: 0.69, blue: 0.22))
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    @objc func openHistoryWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openCalendarWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "hermes" {
                if url.host == "calendar" {
                    // Open calendar window via keyboard shortcut workaround
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set delegate first
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied - please enable in System Settings")
                }
            } catch {
                print("❌ Failed to request notification permission: \(error)")
            }
        }
        
        // Register notification categories with actions
        let joinAction = UNNotificationAction(
            identifier: "JOIN_MEETING",
            title: "Join & Record",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        let meetingCategory = UNNotificationCategory(
            identifier: "MEETING_REMINDER",
            actions: [joinAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([meetingCategory])
        
        // Start calendar sync
        GoogleCalendarService.shared.startPeriodicSync()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        print("📬 Notification tapped: \(response.actionIdentifier)")
        print("📬 UserInfo: \(userInfo)")
        
        // Handle both clicking the notification and the "Join & Record" action
        if response.actionIdentifier == "JOIN_MEETING" || 
           response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            
            let meetingTitle = userInfo["meetingTitle"] as? String ?? "Meeting"
            let meetingURL = userInfo["meetingURL"] as? String
            let meetingId = userInfo["meetingId"] as? String ?? UUID().uuidString
            
            Task { @MainActor in
                // Try to find the meeting in state first
                if let existingMeeting = AppState.shared.upcomingMeetings.first(where: { $0.id == meetingId }) {
                    await MeetingManager.shared.joinAndRecord(meeting: existingMeeting)
                } else {
                    // Create a temporary meeting from notification data
                    let meeting = Meeting(
                        id: meetingId,
                        title: meetingTitle,
                        startTime: Date(),
                        endTime: Date().addingTimeInterval(3600),
                        meetingURL: meetingURL,
                        calendarId: nil
                    )
                    await MeetingManager.shared.joinAndRecord(meeting: meeting)
                }
            }
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

