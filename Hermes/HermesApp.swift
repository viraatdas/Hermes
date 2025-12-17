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
            title: "🎙️ Join & Record",
            options: [.foreground, .authenticationRequired]
        )
        
        let joinOnlyAction = UNNotificationAction(
            identifier: "JOIN_ONLY",
            title: "Join Only",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let meetingCategory = UNNotificationCategory(
            identifier: "MEETING_REMINDER",
            actions: [joinAction, joinOnlyAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([meetingCategory])
        
        // Start calendar sync
        Task {
            await GoogleCalendarService.shared.startPeriodicSync()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        print("📬 Notification tapped: \(response.actionIdentifier)")
        print("📬 UserInfo: \(userInfo)")
        
        let meetingTitle = userInfo["meetingTitle"] as? String ?? "Meeting"
        let meetingURL = userInfo["meetingURL"] as? String
        let meetingId = userInfo["meetingId"] as? String ?? UUID().uuidString
        
        // Handle different actions
        switch response.actionIdentifier {
        case "JOIN_MEETING", UNNotificationDefaultActionIdentifier:
            // Join AND record
            Task { @MainActor in
                if let existingMeeting = AppState.shared.upcomingMeetings.first(where: { $0.id == meetingId }) {
                    await MeetingManager.shared.joinAndRecord(meeting: existingMeeting)
                } else {
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
            
        case "JOIN_ONLY":
            // Just open the meeting URL without recording
            if let urlString = meetingURL, let url = URL(string: urlString) {
                Task { @MainActor in
                    NSWorkspace.shared.open(url)
                }
            }
            
        case "DISMISS":
            // User explicitly dismissed
            print("📬 User dismissed notification for: \(meetingTitle)")
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

