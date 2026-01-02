import Foundation
import ServiceManagement

class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    
    private init() {}
    
    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return false
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                        print("✅ Launch at login enabled")
                    } else {
                        try SMAppService.mainApp.unregister()
                        print("✅ Launch at login disabled")
                    }
                } catch {
                    print("❌ Failed to set launch at login: \(error)")
                }
            }
        }
    }
}






