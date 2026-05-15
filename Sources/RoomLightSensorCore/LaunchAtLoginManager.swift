import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var statusLabel = "Unknown"
    @Published private(set) var lastErrorMessage: String?

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            isEnabled = true
            statusLabel = "Enabled"
        case .notRegistered:
            isEnabled = false
            statusLabel = "Off"
        case .requiresApproval:
            isEnabled = true
            statusLabel = "Needs approval"
        case .notFound:
            isEnabled = false
            statusLabel = "Unavailable"
        @unknown default:
            isEnabled = settings.launchAtLoginEnabled
            statusLabel = "Unknown"
        }
        settings.setLaunchAtLoginEnabled(isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
