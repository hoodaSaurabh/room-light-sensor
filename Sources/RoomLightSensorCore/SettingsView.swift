import AppKit
import SwiftUI

@MainActor
final class SettingsViewFocusCoordinator: ObservableObject {
    @Published private(set) var clearFocusRequestID = 0

    func clearFocus() {
        clearFocusRequestID += 1
    }
}

struct SettingsView: View {
    private enum ThresholdField: Hashable {
        case low
        case high
    }

    @ObservedObject var settings: SettingsStore
    @ObservedObject var monitor: LuxMonitor
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @ObservedObject var focusCoordinator: SettingsViewFocusCoordinator
    @State private var lowThresholdText: String
    @State private var highThresholdText: String
    @State private var previousFocusedThresholdField: ThresholdField?
    @FocusState private var focusedThresholdField: ThresholdField?

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimum = 0
        return formatter
    }()

    init(
        settings: SettingsStore,
        monitor: LuxMonitor,
        notificationManager: NotificationManager,
        launchAtLoginManager: LaunchAtLoginManager,
        focusCoordinator: SettingsViewFocusCoordinator
    ) {
        self.settings = settings
        self.monitor = monitor
        self.notificationManager = notificationManager
        self.launchAtLoginManager = launchAtLoginManager
        self.focusCoordinator = focusCoordinator
        _lowThresholdText = State(initialValue: Self.thresholdText(for: settings.lowThreshold))
        _highThresholdText = State(initialValue: Self.thresholdText(for: settings.highThreshold))
    }

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
        .onAppear {
            syncThresholdTexts(force: true)
            clearThresholdFocus()
        }
        .onChange(of: settings.lowThreshold) { _ in
            syncThresholdTexts()
        }
        .onChange(of: settings.highThreshold) { _ in
            syncThresholdTexts()
        }
        .onChange(of: lowThresholdText) { text in
            persistThresholdText(text, for: .low)
        }
        .onChange(of: highThresholdText) { text in
            persistThresholdText(text, for: .high)
        }
        .onChange(of: focusedThresholdField) { newField in
            if let previousFocusedThresholdField,
               previousFocusedThresholdField != newField {
                commitThreshold(previousFocusedThresholdField)
            }

            previousFocusedThresholdField = newField
        }
        .onChange(of: focusCoordinator.clearFocusRequestID) { _ in
            clearThresholdFocus()
        }
        .onDisappear {
            clearThresholdFocus()
        }
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
                text: $lowThresholdText,
                field: .low,
                value: lowThresholdBinding,
                range: 0...max(0, settings.highThreshold - ThresholdConfiguration.minimumGap)
            )

            thresholdRow(
                title: "High",
                text: $highThresholdText,
                field: .high,
                value: highThresholdBinding,
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
        text: Binding<String>,
        field: ThresholdField,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 86)
                .focused($focusedThresholdField, equals: field)
                .onSubmit {
                    commitAndClearThreshold(field)
                }
            Text("lux")
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: 5)
                .labelsHidden()
                .frame(width: 56)
        }
    }

    private var lowThresholdBinding: Binding<Double> {
        Binding(
            get: { settings.lowThreshold },
            set: { value in
                settings.setLowThreshold(value)
                syncThresholdTexts(force: true)
            }
        )
    }

    private var highThresholdBinding: Binding<Double> {
        Binding(
            get: { settings.highThreshold },
            set: { value in
                settings.setHighThreshold(value)
                syncThresholdTexts(force: true)
            }
        )
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

    private func commitThreshold(_ field: ThresholdField) {
        let text = switch field {
        case .low:
            lowThresholdText
        case .high:
            highThresholdText
        }

        guard let value = Self.thresholdValue(from: text) else {
            syncThresholdTexts(force: true)
            return
        }

        switch field {
        case .low:
            settings.setLowThreshold(value)
        case .high:
            settings.setHighThreshold(value)
        }

        syncThresholdTexts(force: true)
    }

    private func commitAndClearThreshold(_ field: ThresholdField) {
        commitThreshold(field)
        focusedThresholdField = nil
        previousFocusedThresholdField = nil
    }

    private func persistThresholdText(_ text: String, for field: ThresholdField) {
        guard focusedThresholdField == field,
              let value = Self.thresholdValue(from: text) else {
            return
        }

        switch field {
        case .low:
            settings.setLowThreshold(value)
        case .high:
            settings.setHighThreshold(value)
        }
    }

    private func clearThresholdFocus() {
        if let focusedThresholdField {
            commitThreshold(focusedThresholdField)
        }

        focusedThresholdField = nil
        previousFocusedThresholdField = nil
    }

    private func syncThresholdTexts(force: Bool = false) {
        if force || focusedThresholdField != .low {
            lowThresholdText = Self.thresholdText(for: settings.lowThreshold)
        }

        if force || focusedThresholdField != .high {
            highThresholdText = Self.thresholdText(for: settings.highThreshold)
        }
    }

    private static func thresholdText(for value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func thresholdValue(from text: String) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        if let number = numberFormatter.number(from: trimmedText) {
            return number.doubleValue
        }

        return Double(trimmedText)
    }
}
