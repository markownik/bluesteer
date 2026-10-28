import Foundation
import ServiceManagement

/// "Start at login" through SMAppService; only meaningful for a bundled .app.
public enum LoginItem {
    public static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    public static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    public static func setEnabled(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    public static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
