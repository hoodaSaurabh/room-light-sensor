import XCTest
@testable import RoomLightSensorCore

@MainActor
final class LuxMonitorTests: XCTestCase {
    func testMonitorPublishesLuxReading() {
        let defaults = isolatedDefaults()
        let settings = SettingsStore(defaults: defaults)
        let alerts = MockAlertDeliverer()
        let monitor = LuxMonitor(
            provider: MockAmbientLightProvider(readings: [123]),
            settings: settings,
            alertDeliverer: alerts
        )

        monitor.sampleOnce()

        XCTAssertEqual(monitor.currentLux, 123)
        XCTAssertEqual(monitor.status, .reading)
        XCTAssertTrue(alerts.alerts.isEmpty)
    }

    func testMonitorPublishesUnavailableState() {
        let defaults = isolatedDefaults()
        let settings = SettingsStore(defaults: defaults)
        let monitor = LuxMonitor(
            provider: MockAmbientLightProvider(results: [.failure(AmbientLightReadError.sensorUnavailable)]),
            settings: settings,
            alertDeliverer: nil
        )

        monitor.sampleOnce()

        XCTAssertNil(monitor.currentLux)
        XCTAssertEqual(monitor.status, .unavailable)
    }

    func testMonitorDeliversThresholdAlert() {
        let defaults = isolatedDefaults()
        defaults.set(50, forKey: "lowThreshold")
        defaults.set(1_000, forKey: "highThreshold")
        defaults.set(0, forKey: "alertCooldownSeconds")
        let settings = SettingsStore(defaults: defaults)
        let alerts = MockAlertDeliverer()
        let monitor = LuxMonitor(
            provider: MockAmbientLightProvider(readings: [40]),
            settings: settings,
            alertDeliverer: alerts,
            now: { Date(timeIntervalSince1970: 500) }
        )

        monitor.sampleOnce()

        XCTAssertEqual(alerts.alerts.count, 1)
        XCTAssertEqual(alerts.alerts.first?.kind, .low)
        XCTAssertEqual(alerts.luxValues, [40])
    }

    func testShowLuxInMenuBarDefaultsToOnAndPersists() {
        let defaults = isolatedDefaults()
        let settings = SettingsStore(defaults: defaults)

        XCTAssertTrue(settings.showLuxInMenuBar)

        settings.setShowLuxInMenuBar(false)

        XCTAssertFalse(SettingsStore(defaults: defaults).showLuxInMenuBar)
    }

    func testThresholdDefaults() {
        let defaults = isolatedDefaults()
        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.lowThreshold, 75)
        XCTAssertEqual(settings.highThreshold, 300)
    }

    func testSettingLowThresholdPreservesEnteredValueAndRaisesHighWhenNeeded() {
        let defaults = isolatedDefaults()
        let settings = SettingsStore(defaults: defaults)

        settings.setLowThreshold(500)

        XCTAssertEqual(settings.lowThreshold, 500)
        XCTAssertEqual(settings.highThreshold, 501)
    }

    func testSettingHighThresholdPreservesEnteredValueAndLowersLowWhenNeeded() {
        let defaults = isolatedDefaults()
        let settings = SettingsStore(defaults: defaults)

        settings.setHighThreshold(50)

        XCTAssertEqual(settings.lowThreshold, 49)
        XCTAssertEqual(settings.highThreshold, 50)
    }

    func testMigratesLegacyDefaultsWhenRequested() {
        let defaults = isolatedDefaults()
        let legacyDefaults = isolatedDefaults()
        legacyDefaults.set(25, forKey: "lowThreshold")
        legacyDefaults.set(450, forKey: "highThreshold")
        legacyDefaults.set(false, forKey: "notificationsEnabled")
        legacyDefaults.set(false, forKey: "showLuxInMenuBar")
        legacyDefaults.set(42, forKey: "alertCooldownSeconds")

        let settings = SettingsStore(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            migrateLegacyDefaults: true
        )

        XCTAssertEqual(settings.lowThreshold, 25)
        XCTAssertEqual(settings.highThreshold, 450)
        XCTAssertFalse(settings.notificationsEnabled)
        XCTAssertFalse(settings.showLuxInMenuBar)
        XCTAssertEqual(settings.alertCooldownSeconds, 42)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "RoomLightSensorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class MockAlertDeliverer: AlertDelivering {
    private(set) var alerts: [ThresholdAlert] = []
    private(set) var luxValues: [Double] = []

    func deliver(alert: ThresholdAlert, lux: Double) {
        alerts.append(alert)
        luxValues.append(lux)
    }
}
