import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let lowThreshold = "lowThreshold"
        static let highThreshold = "highThreshold"
        static let notificationsEnabled = "notificationsEnabled"
        static let showLuxInMenuBar = "showLuxInMenuBar"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let alertCooldownSeconds = "alertCooldownSeconds"
    }

    private let defaults: UserDefaults

    @Published private(set) var lowThreshold: Double
    @Published private(set) var highThreshold: Double
    @Published private(set) var notificationsEnabled: Bool
    @Published private(set) var showLuxInMenuBar: Bool
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var alertCooldownSeconds: TimeInterval

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let configuration = ThresholdConfiguration(
            low: defaults.doubleValue(
                forKey: Key.lowThreshold,
                default: ThresholdConfiguration.defaultLow
            ),
            high: defaults.doubleValue(
                forKey: Key.highThreshold,
                default: ThresholdConfiguration.defaultHigh
            ),
            cooldown: defaults.doubleValue(
                forKey: Key.alertCooldownSeconds,
                default: ThresholdConfiguration.defaultCooldown
            )
        )

        self.lowThreshold = configuration.low
        self.highThreshold = configuration.high
        self.alertCooldownSeconds = configuration.cooldown
        self.notificationsEnabled = defaults.boolValue(forKey: Key.notificationsEnabled, default: true)
        self.showLuxInMenuBar = defaults.boolValue(forKey: Key.showLuxInMenuBar, default: true)
        self.launchAtLoginEnabled = defaults.boolValue(forKey: Key.launchAtLoginEnabled, default: false)

        persistThresholds()
    }

    var thresholdConfiguration: ThresholdConfiguration {
        ThresholdConfiguration(
            low: lowThreshold,
            high: highThreshold,
            cooldown: alertCooldownSeconds
        )
    }

    func setLowThreshold(_ value: Double) {
        let safeValue = value.isFinite ? max(0, value) : ThresholdConfiguration.defaultLow
        lowThreshold = min(safeValue, highThreshold - ThresholdConfiguration.minimumGap)
        persistThresholds()
    }

    func setHighThreshold(_ value: Double) {
        let safeValue = value.isFinite ? max(0, value) : ThresholdConfiguration.defaultHigh
        highThreshold = max(safeValue, lowThreshold + ThresholdConfiguration.minimumGap)
        persistThresholds()
    }

    func setAlertCooldownSeconds(_ value: TimeInterval) {
        let safeValue = value.isFinite ? max(0, value) : ThresholdConfiguration.defaultCooldown
        alertCooldownSeconds = safeValue
        defaults.set(alertCooldownSeconds, forKey: Key.alertCooldownSeconds)
    }

    func setNotificationsEnabled(_ value: Bool) {
        notificationsEnabled = value
        defaults.set(value, forKey: Key.notificationsEnabled)
    }

    func setShowLuxInMenuBar(_ value: Bool) {
        showLuxInMenuBar = value
        defaults.set(value, forKey: Key.showLuxInMenuBar)
    }

    func setLaunchAtLoginEnabled(_ value: Bool) {
        launchAtLoginEnabled = value
        defaults.set(value, forKey: Key.launchAtLoginEnabled)
    }

    private func persistThresholds() {
        defaults.set(lowThreshold, forKey: Key.lowThreshold)
        defaults.set(highThreshold, forKey: Key.highThreshold)
        defaults.set(alertCooldownSeconds, forKey: Key.alertCooldownSeconds)
    }
}

private extension UserDefaults {
    func doubleValue(forKey key: String, default defaultValue: Double) -> Double {
        guard object(forKey: key) != nil else {
            return defaultValue
        }
        return double(forKey: key)
    }

    func boolValue(forKey key: String, default defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else {
            return defaultValue
        }
        return bool(forKey: key)
    }
}
