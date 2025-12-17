import Foundation
import ScreenCaptureKit
import Combine

@MainActor
class ScreenShareDetector: ObservableObject {
    static let shared = ScreenShareDetector()
    
    @Published var isScreenSharing = false
    
    private var timer: Timer?
    
    // Common screen sharing app bundle identifiers
    private let screenSharingApps = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.google.Chrome",  // Google Meet runs in Chrome
        "com.brave.Browser",
        "org.mozilla.firefox",
        "com.apple.Safari",
        "com.cisco.webexmeetingsapp",
        "com.webex.meetingmanager",
        "com.slack.Slack",
        "com.discord.Discord"
    ]
    
    private init() {}
    
    func startMonitoring() {
        // Check every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkScreenSharing()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkScreenSharing() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            // Check if any screen sharing window is active
            // This is a heuristic - we look for windows from known screen sharing apps
            // that have "sharing" indicators or specific window titles
            
            let sharingIndicators = content.windows.contains { window in
                let title = window.title?.lowercased() ?? ""
                let appName = window.owningApplication?.applicationName.lowercased() ?? ""
                
                // Check for common screen sharing indicators
                let sharingKeywords = ["screen share", "sharing screen", "share screen", 
                                      "you are sharing", "presenting", "screen sharing"]
                
                for keyword in sharingKeywords {
                    if title.contains(keyword) || appName.contains(keyword) {
                        return true
                    }
                }
                
                return false
            }
            
            // Also check for the macOS screen recording indicator
            let hasScreenRecordingIndicator = checkMacOSScreenRecordingIndicator()
            
            await MainActor.run {
                // We consider screen sharing active if we detect indicators
                // but we're NOT the one doing the recording
                let wasSharing = self.isScreenSharing
                self.isScreenSharing = sharingIndicators || hasScreenRecordingIndicator
                
                if self.isScreenSharing != wasSharing {
                    self.notifyScreenShareChange()
                }
            }
        } catch {
            print("Failed to check screen sharing: \(error)")
        }
    }
    
    private func checkMacOSScreenRecordingIndicator() -> Bool {
        // Check if the screen recording menu bar icon is visible
        // This is tricky to detect directly, so we use an approximation
        
        // Check running processes for screen sharing tools
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            
            // Check if it's a known screen sharing app and is active
            if screenSharingApps.contains(bundleId) && app.isActive {
                // The app is in the foreground - user might be in a meeting
                // We can't definitively know if they're sharing their screen
                // but we can be cautious
                return false // Don't hide just because a meeting app is active
            }
        }
        
        return false
    }
    
    private func notifyScreenShareChange() {
        if isScreenSharing {
            print("Screen sharing detected - hiding Hermes UI")
            // Post notification for UI to respond
            NotificationCenter.default.post(name: .screenShareStarted, object: nil)
        } else {
            print("Screen sharing ended - showing Hermes UI")
            NotificationCenter.default.post(name: .screenShareEnded, object: nil)
        }
    }
}

extension Notification.Name {
    static let screenShareStarted = Notification.Name("screenShareStarted")
    static let screenShareEnded = Notification.Name("screenShareEnded")
}





