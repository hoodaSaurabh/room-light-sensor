import RoomLightSensorCore
import AppKit

@main
struct RoomLightSensorMain {
    @MainActor
    static func main() {
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
        _ = delegate
    }
}
