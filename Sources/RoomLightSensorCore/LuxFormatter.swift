import Foundation

enum LuxFormatter {
    static func string(for lux: Double) -> String {
        guard lux.isFinite else {
            return "-- lux"
        }

        if lux >= 100 {
            return "\(Int(lux.rounded())) lux"
        }

        if lux >= 10 {
            return String(format: "%.1f lux", lux)
        }

        return String(format: "%.2f lux", lux)
    }

    static func menuBarString(for lux: Double?) -> String {
        guard let lux, lux.isFinite else {
            return "-- lx"
        }

        return "\(Int(lux.rounded())) lx"
    }
}
