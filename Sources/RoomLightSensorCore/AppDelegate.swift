import AppKit

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
}
