import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, AlertDelivering {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastErrorMessage: String?

    private let settings: SettingsStore
    private let center: UNUserNotificationCenter

    init(
        settings: SettingsStore,
        center: UNUserNotificationCenter = .current()
    ) {
        self.settings = settings
        self.center = center
        super.init()
        center.delegate = self
        refreshAuthorizationStatus()
    }

    var permissionLabel: String {
        switch authorizationStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not requested"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.lastErrorMessage = error.localizedDescription
                }
                self?.refreshAuthorizationStatus()
            }
        }
    }

    func deliver(alert: ThresholdAlert, lux: Double) {
        guard settings.notificationsEnabled else {
            return
        }

        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            if authorizationStatus == .notDetermined {
                requestAuthorizationIfNeeded()
            }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title(for: alert.kind)
        content.body = body(for: alert, lux: lux)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ambient-light-\(alert.kind.rawValue)-\(Int(alert.date.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        center.add(request) { [weak self] error in
            guard let error else {
                return
            }
            Task { @MainActor in
                self?.lastErrorMessage = error.localizedDescription
            }
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func title(for kind: ThresholdAlertKind) -> String {
        switch kind {
        case .low:
            return "Ambient light is below threshold"
        case .high:
            return "Ambient light is above threshold"
        }
    }

    private func body(for alert: ThresholdAlert, lux: Double) -> String {
        switch alert.kind {
        case .low:
            return "Current reading: \(LuxFormatter.string(for: lux)). Low threshold: \(LuxFormatter.string(for: alert.threshold))."
        case .high:
            return "Current reading: \(LuxFormatter.string(for: lux)). High threshold: \(LuxFormatter.string(for: alert.threshold))."
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
