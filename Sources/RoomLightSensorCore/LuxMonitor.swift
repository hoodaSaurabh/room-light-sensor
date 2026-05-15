import Combine
import Foundation

enum SensorStatus: Equatable {
    case waiting
    case reading
    case unavailable
    case failed(String)

    var displayText: String {
        switch self {
        case .waiting:
            return "Waiting for first reading"
        case .reading:
            return "Monitoring"
        case .unavailable:
            return "Sensor unavailable"
        case .failed(let message):
            return message
        }
    }
}

@MainActor
protocol AlertDelivering: AnyObject {
    func deliver(alert: ThresholdAlert, lux: Double)
}

@MainActor
final class LuxMonitor: ObservableObject {
    @Published private(set) var currentLux: Double?
    @Published private(set) var status: SensorStatus = .waiting
    @Published private(set) var lastSampleDate: Date?
    @Published private(set) var lastAlert: ThresholdAlert?

    private let provider: AmbientLightProvider
    private let settings: SettingsStore
    private weak var alertDeliverer: AlertDelivering?
    private let now: () -> Date
    private var timer: Timer?
    private var evaluator = ThresholdEvaluator()

    init(
        provider: AmbientLightProvider,
        settings: SettingsStore,
        alertDeliverer: AlertDelivering?,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.settings = settings
        self.alertDeliverer = alertDeliverer
        self.now = now
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else {
            return
        }

        sampleOnce()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleOnce()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func sampleOnce() {
        do {
            let lux = try provider.readLux()
            currentLux = lux
            lastSampleDate = now()
            status = .reading

            if settings.notificationsEnabled,
               let alert = evaluator.evaluate(
                lux: lux,
                configuration: settings.thresholdConfiguration,
                now: lastSampleDate ?? now()
               ) {
                lastAlert = alert
                alertDeliverer?.deliver(alert: alert, lux: lux)
            }
        } catch let error as AmbientLightReadError {
            currentLux = nil
            lastSampleDate = now()
            switch error {
            case .sensorUnavailable:
                status = .unavailable
            case .invalidLuxValue, .ioKitError:
                status = .failed(error.localizedDescription)
            }
        } catch {
            currentLux = nil
            lastSampleDate = now()
            status = .failed(error.localizedDescription)
        }
    }
}
