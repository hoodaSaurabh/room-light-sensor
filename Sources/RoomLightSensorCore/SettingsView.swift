import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var monitor: LuxMonitor
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimum = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            menuBarControls
            thresholdControls
            notificationControls
            launchAtLoginControls
            Divider()
            footer
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(width: 360)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(currentLuxText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        Image(systemName: statusSymbolName)
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(statusColor)
            .accessibilityLabel(monitor.status.displayText)
    }

    private var menuBarControls: some View {
        Toggle(
            "Show Lux units in the menu bar",
            isOn: Binding(
                get: { settings.showLuxInMenuBar },
                set: { value in settings.setShowLuxInMenuBar(value) }
            )
        )
        .toggleStyle(.switch)
    }

    private var thresholdControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notification thresholds")
                .font(.headline)

            thresholdRow(
                title: "Low",
                value: Binding(
                    get: { settings.lowThreshold },
                    set: { settings.setLowThreshold($0) }
                ),
                range: 0...max(0, settings.highThreshold - ThresholdConfiguration.minimumGap)
            )

            thresholdRow(
                title: "High",
                value: Binding(
                    get: { settings.highThreshold },
                    set: { settings.setHighThreshold($0) }
                ),
                range: (settings.lowThreshold + ThresholdConfiguration.minimumGap)...10_000
            )

            HStack {
                Text("Time between notifications")
                Spacer()
                Stepper(
                    value: Binding(
                        get: { settings.alertCooldownSeconds / 60 },
                        set: { settings.setAlertCooldownSeconds($0 * 60) }
                    ),
                    in: 0...60,
                    step: 1
                ) {
                    Text("\(Int(settings.alertCooldownSeconds / 60)) min")
                        .monospacedDigit()
                        .frame(width: 54, alignment: .trailing)
                }
            }
        }
    }

    private func thresholdRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, formatter: Self.numberFormatter)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 86)
            Text("lux")
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: 5)
                .labelsHidden()
                .frame(width: 56)
        }
    }

    private var notificationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "Notifications",
                isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { enabled in
                        settings.setNotificationsEnabled(enabled)
                        if enabled {
                            notificationManager.requestAuthorizationIfNeeded()
                        }
                    }
                )
            )
            .toggleStyle(.switch)

            if notificationManager.authorizationStatus == .denied {
                Button("Open Notification Settings") {
                    notificationManager.openNotificationSettings()
                }
            }

            if let message = notificationManager.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var launchAtLoginControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { launchAtLoginManager.setEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            if launchAtLoginManager.statusLabel == "Needs approval" {
                Button("Open Login Items") {
                    launchAtLoginManager.openSystemSettings()
                }
            }

            if let message = launchAtLoginManager.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var currentLuxText: String {
        guard let currentLux = monitor.currentLux else {
            return "-- lux"
        }
        return LuxFormatter.string(for: currentLux)
    }

    private var statusSymbolName: String {
        switch monitor.status {
        case .reading:
            return "checkmark.circle.fill"
        case .waiting:
            return "clock.fill"
        case .unavailable, .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch monitor.status {
        case .reading:
            return .green
        case .waiting:
            return .secondary
        case .unavailable, .failed:
            return .orange
        }
    }
}
