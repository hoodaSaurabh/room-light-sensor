import Foundation

enum ThresholdAlertKind: String, Equatable {
    case low
    case high
}

struct ThresholdAlert: Equatable {
    let kind: ThresholdAlertKind
    let threshold: Double
    let date: Date
}

struct ThresholdConfiguration: Equatable {
    static let defaultLow: Double = 75
    static let defaultHigh: Double = 300
    static let defaultCooldown: TimeInterval = 5 * 60
    static let defaultHysteresis: Double = 5
    static let minimumGap: Double = 1

    let low: Double
    let high: Double
    let cooldown: TimeInterval
    let hysteresis: Double

    init(
        low: Double = Self.defaultLow,
        high: Double = Self.defaultHigh,
        cooldown: TimeInterval = Self.defaultCooldown,
        hysteresis: Double = Self.defaultHysteresis
    ) {
        let normalized = Self.normalized(
            low: low,
            high: high,
            cooldown: cooldown,
            hysteresis: hysteresis
        )
        self.low = normalized.low
        self.high = normalized.high
        self.cooldown = normalized.cooldown
        self.hysteresis = normalized.hysteresis
    }

    static func normalized(
        low: Double,
        high: Double,
        cooldown: TimeInterval,
        hysteresis: Double
    ) -> ThresholdConfiguration {
        let safeLow = low.isFinite ? max(0, low) : defaultLow
        let safeHighInput = high.isFinite ? max(0, high) : defaultHigh
        let safeHigh = max(safeHighInput, safeLow + minimumGap)
        let safeCooldown = cooldown.isFinite ? max(0, cooldown) : defaultCooldown
        let safeHysteresisInput = hysteresis.isFinite ? max(0, hysteresis) : defaultHysteresis
        let safeHysteresis = min(safeHysteresisInput, max(0, (safeHigh - safeLow) / 2))

        return ThresholdConfiguration(
            uncheckedLow: safeLow,
            high: safeHigh,
            cooldown: safeCooldown,
            hysteresis: safeHysteresis
        )
    }

    private init(
        uncheckedLow low: Double,
        high: Double,
        cooldown: TimeInterval,
        hysteresis: Double
    ) {
        self.low = low
        self.high = high
        self.cooldown = cooldown
        self.hysteresis = hysteresis
    }
}

struct ThresholdEvaluator {
    private var lowArmed = true
    private var highArmed = true
    private var lastDeliveredAlertDate: Date?

    mutating func evaluate(
        lux: Double,
        configuration: ThresholdConfiguration,
        now: Date
    ) -> ThresholdAlert? {
        guard lux.isFinite else {
            return nil
        }

        if lux >= configuration.low + configuration.hysteresis {
            lowArmed = true
        }

        if lux <= configuration.high - configuration.hysteresis {
            highArmed = true
        }

        if lux < configuration.low, lowArmed {
            lowArmed = false
            return alertIfAllowed(
                kind: .low,
                threshold: configuration.low,
                cooldown: configuration.cooldown,
                now: now
            )
        }

        if lux > configuration.high, highArmed {
            highArmed = false
            return alertIfAllowed(
                kind: .high,
                threshold: configuration.high,
                cooldown: configuration.cooldown,
                now: now
            )
        }

        return nil
    }

    private mutating func alertIfAllowed(
        kind: ThresholdAlertKind,
        threshold: Double,
        cooldown: TimeInterval,
        now: Date
    ) -> ThresholdAlert? {
        if let lastDeliveredAlertDate,
           now.timeIntervalSince(lastDeliveredAlertDate) < cooldown {
            return nil
        }

        lastDeliveredAlertDate = now
        return ThresholdAlert(kind: kind, threshold: threshold, date: now)
    }
}
