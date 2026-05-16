import Foundation
import IOKit

protocol AmbientLightProvider {
    func readLux() throws -> Double
}

enum AmbientLightReadError: Error, Equatable, LocalizedError {
    case sensorUnavailable
    case invalidLuxValue
    case ioKitError(kern_return_t)

    var errorDescription: String? {
        switch self {
        case .sensorUnavailable:
            return "No compatible ambient light sensor was found."
        case .invalidLuxValue:
            return "The ambient light sensor returned an invalid value."
        case .ioKitError(let code):
            return "IOKit returned error code \(code)."
        }
    }
}

final class IORegistryAmbientLightProvider: AmbientLightProvider {
    private let luxPropertyName = "CurrentLux" as CFString
    private var cachedService: io_registry_entry_t = 0

    deinit {
        invalidateCachedService()
    }

    func readLux() throws -> Double {
        if cachedService != 0 {
            if let lux = try readLux(from: cachedService) {
                return lux
            }
            invalidateCachedService()
        }

        return try findAndCacheLuxService()
    }

    private func findAndCacheLuxService() throws -> Double {
        var iterator: io_iterator_t = 0
        let result = IORegistryCreateIterator(
            kIOMainPortDefault,
            kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        )

        guard result == KERN_SUCCESS else {
            throw AmbientLightReadError.ioKitError(result)
        }

        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else {
                break
            }

            do {
                guard let lux = try readLux(from: service) else {
                    IOObjectRelease(service)
                    continue
                }

                cacheService(service)
                return lux
            } catch {
                IOObjectRelease(service)
                throw error
            }
        }

        throw AmbientLightReadError.sensorUnavailable
    }

    private func readLux(from service: io_registry_entry_t) throws -> Double? {
        guard let value = IORegistryEntryCreateCFProperty(
            service,
            luxPropertyName,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }

        guard let lux = Self.doubleValue(from: value), lux.isFinite, lux >= 0 else {
            throw AmbientLightReadError.invalidLuxValue
        }

        return lux
    }

    private func cacheService(_ service: io_registry_entry_t) {
        if cachedService != 0, cachedService != service {
            IOObjectRelease(cachedService)
        }
        cachedService = service
    }

    private func invalidateCachedService() {
        if cachedService != 0 {
            IOObjectRelease(cachedService)
            cachedService = 0
        }
    }

    private static func doubleValue(from value: CFTypeRef) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if CFGetTypeID(value) == CFNumberGetTypeID() {
            var doubleValue = 0.0
            let didConvert = CFNumberGetValue((value as! CFNumber), .doubleType, &doubleValue)
            return didConvert ? doubleValue : nil
        }

        return nil
    }
}

final class MockAmbientLightProvider: AmbientLightProvider {
    private var results: [Result<Double, Error>]
    private var lastLux: Double?

    init(readings: [Double]) {
        self.results = readings.map { .success($0) }
    }

    init(results: [Result<Double, Error>]) {
        self.results = results
    }

    func readLux() throws -> Double {
        guard !results.isEmpty else {
            if let lastLux {
                return lastLux
            }
            throw AmbientLightReadError.sensorUnavailable
        }

        switch results.removeFirst() {
        case .success(let lux):
            lastLux = lux
            return lux
        case .failure(let error):
            throw error
        }
    }
}
