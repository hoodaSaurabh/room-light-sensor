import RoomLightSensorCore
import AppKit
import Darwin
import Foundation

@main
struct RoomLightSensorMain {
    private static var singleInstanceLockFileDescriptor: Int32 = -1
    private static let appSupportFolderName = "Room Light Sensor"
    private static let singleInstanceLockFileName = "com.hooda.room-light-sensor.lock"

    @MainActor
    static func main() {
        guard acquireSingleInstanceLock() else {
            return
        }

        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
        _ = delegate
    }

    private static func acquireSingleInstanceLock() -> Bool {
        guard let lockFilePath = singleInstanceLockFilePath() else {
            return true
        }

        let fileDescriptor = open(lockFilePath, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return true
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            return false
        }

        singleInstanceLockFileDescriptor = fileDescriptor
        return true
    }

    private static func singleInstanceLockFilePath() -> String? {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let directoryURL = applicationSupportURL.appendingPathComponent(appSupportFolderName, isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            return nil
        }

        return directoryURL.appendingPathComponent(singleInstanceLockFileName).path
    }
}
