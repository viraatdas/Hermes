import Foundation
import ScreenCaptureKit
import Combine

@MainActor
class ScreenShareDetector: ObservableObject {
    static let shared = ScreenShareDetector()
    
    @Published var isScreenSharing = false
    
    private var timer: Timer?

    private init() {}
    
    func startMonitoring() {
        guard timer == nil else { return }   // idempotent: safe to call from launch + recording
        // Check every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkScreenSharing()
            }
        }
        Task { await checkScreenSharing() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // Window titles the major meeting apps give their "you are sharing" controls.
    private let sharingKeywords = [
        "you are screen sharing", "you're screen sharing", "you are sharing your screen",
        "stop share", "stop sharing", "sharing your screen", "screen sharing",
        "you are presenting", "you're presenting", "presenting to everyone",
        "share toolbar", "sharing toolbar", "zsharetoolbar", "as_toolbar",
        "screen broadcast", "is sharing your screen"
    ]

    private func checkScreenSharing() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            let sharing = content.windows.contains { window in
                guard window.isOnScreen else { return false }
                let title = (window.title ?? "").lowercased()
                guard !title.isEmpty else { return false }
                return sharingKeywords.contains { title.contains($0) }
            }

            let wasSharing = isScreenSharing
            isScreenSharing = sharing
            AppState.shared.isScreenSharing = sharing

            if sharing != wasSharing {
                notifyScreenShareChange()
            }
        } catch {
            // Missing Screen Recording permission or transient failure — leave state unchanged.
        }
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






