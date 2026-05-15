import XCTest
@testable import RoomLightSensorCore

final class ThresholdEvaluatorTests: XCTestCase {
    func testConfigurationNormalizesInvalidThresholds() {
        let configuration = ThresholdConfiguration(
            low: -10,
            high: -5,
            cooldown: -30,
            hysteresis: 100
        )

        XCTAssertEqual(configuration.low, 0)
        XCTAssertEqual(configuration.high, ThresholdConfiguration.minimumGap)
        XCTAssertEqual(configuration.cooldown, 0)
        XCTAssertEqual(configuration.hysteresis, 0.5)
    }

    func testLowThresholdAlertsOnceUntilRearmedByHysteresis() {
        var evaluator = ThresholdEvaluator()
        let configuration = ThresholdConfiguration(low: 50, high: 1_000, cooldown: 0, hysteresis: 5)
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            evaluator.evaluate(lux: 49, configuration: configuration, now: now)?.kind,
            .low
        )
        XCTAssertNil(evaluator.evaluate(lux: 40, configuration: configuration, now: now.addingTimeInterval(1)))
        XCTAssertNil(evaluator.evaluate(lux: 54, configuration: configuration, now: now.addingTimeInterval(2)))
        XCTAssertNil(evaluator.evaluate(lux: 56, configuration: configuration, now: now.addingTimeInterval(3)))

        XCTAssertEqual(
            evaluator.evaluate(lux: 49, configuration: configuration, now: now.addingTimeInterval(4))?.kind,
            .low
        )
    }

    func testHighThresholdAlertsOnceUntilRearmedByHysteresis() {
        var evaluator = ThresholdEvaluator()
        let configuration = ThresholdConfiguration(low: 50, high: 1_000, cooldown: 0, hysteresis: 5)
        let now = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(
            evaluator.evaluate(lux: 1_001, configuration: configuration, now: now)?.kind,
            .high
        )
        XCTAssertNil(evaluator.evaluate(lux: 1_100, configuration: configuration, now: now.addingTimeInterval(1)))
        XCTAssertNil(evaluator.evaluate(lux: 996, configuration: configuration, now: now.addingTimeInterval(2)))
        XCTAssertNil(evaluator.evaluate(lux: 994, configuration: configuration, now: now.addingTimeInterval(3)))

        XCTAssertEqual(
            evaluator.evaluate(lux: 1_001, configuration: configuration, now: now.addingTimeInterval(4))?.kind,
            .high
        )
    }

    func testCooldownSuppressesRearmedCrossings() {
        var evaluator = ThresholdEvaluator()
        let configuration = ThresholdConfiguration(low: 50, high: 1_000, cooldown: 300, hysteresis: 5)
        let now = Date(timeIntervalSince1970: 300)

        XCTAssertNotNil(evaluator.evaluate(lux: 49, configuration: configuration, now: now))
        XCTAssertNil(evaluator.evaluate(lux: 60, configuration: configuration, now: now.addingTimeInterval(1)))
        XCTAssertNil(evaluator.evaluate(lux: 49, configuration: configuration, now: now.addingTimeInterval(10)))
        XCTAssertNil(evaluator.evaluate(lux: 60, configuration: configuration, now: now.addingTimeInterval(301)))

        XCTAssertNotNil(evaluator.evaluate(lux: 49, configuration: configuration, now: now.addingTimeInterval(302)))
    }
}
