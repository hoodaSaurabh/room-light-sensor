import AppKit
import CoreServices

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore?
    private var notificationManager: NotificationManager?
    private var launchAtLoginManager: LaunchAtLoginManager?
    private var luxMonitor: LuxMonitor?
    private var statusBarController: StatusBarController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        refreshBundleIconRegistration()

        let settings = SettingsStore()
        let notificationManager = NotificationManager(settings: settings)
        let launchAtLoginManager = LaunchAtLoginManager(settings: settings)
        let luxMonitor = LuxMonitor(
            provider: IORegistryAmbientLightProvider(),
            settings: settings,
            alertDeliverer: notificationManager
        )
        let statusBarController = StatusBarController(
            settings: settings,
            monitor: luxMonitor,
            notificationManager: notificationManager,
            launchAtLoginManager: launchAtLoginManager
        )

        self.settings = settings
        self.notificationManager = notificationManager
        self.launchAtLoginManager = launchAtLoginManager
        self.luxMonitor = luxMonitor
        self.statusBarController = statusBarController

        if settings.notificationsEnabled {
            notificationManager.requestAuthorizationIfNeeded()
        }
        luxMonitor.start()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func refreshBundleIconRegistration() {
        // Notification banners use the Launch Services icon cache for the app bundle.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        _ = LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        NSWorkspace.shared.noteFileSystemChanged(Bundle.main.bundleURL.path)
    }
}
