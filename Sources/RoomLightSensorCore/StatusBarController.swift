import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private enum Layout {
        static let menuBarPopoverGap: CGFloat = 6
    }

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let monitor: LuxMonitor
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsStore,
        monitor: LuxMonitor,
        notificationManager: NotificationManager,
        launchAtLoginManager: LaunchAtLoginManager
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.settings = settings
        self.monitor = monitor
        super.init()

        configureStatusItem()
        configurePopover(
            settings: settings,
            monitor: monitor,
            notificationManager: notificationManager,
            launchAtLoginManager: launchAtLoginManager
        )
        bindMonitor()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Room Light Sensor")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.title = "-- lx"
    }

    private func configurePopover(
        settings: SettingsStore,
        monitor: LuxMonitor,
        notificationManager: NotificationManager,
        launchAtLoginManager: LaunchAtLoginManager
    ) {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 470)
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                monitor: monitor,
                notificationManager: notificationManager,
                launchAtLoginManager: launchAtLoginManager
            )
        )
    }

    private func bindMonitor() {
        monitor.$currentLux
            .combineLatest(monitor.$status)
            .combineLatest(settings.$showLuxInMenuBar)
            .sink { [weak self] reading, showLux in
                self?.updateStatusItem(lux: reading.0, status: reading.1, showLux: showLux)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(lux: Double?, status: SensorStatus, showLux: Bool) {
        guard let button = statusItem.button else {
            return
        }

        let wasIconOnly = button.title.isEmpty

        switch status {
        case .unavailable:
            button.title = "No ALS"
        case .failed:
            button.title = "ALS !"
        case .waiting, .reading:
            button.title = showLux ? LuxFormatter.menuBarString(for: lux) : ""
        }

        statusItem.length = button.title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength

        if popover.isShown, wasIconOnly != button.title.isEmpty {
            reanchorPopoverAfterStatusItemResize()
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(from: button)
        }
    }

    private func showPopover(from button: NSStatusBarButton) {
        popover.show(relativeTo: anchorRect(in: button), of: button, preferredEdge: .minY)
        schedulePopoverVerticalPositionUpdate()
        popover.contentViewController?.view.window?.makeKey()
    }

    private func reanchorPopoverAfterStatusItemResize() {
        popover.performClose(nil)

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, let button = self.statusItem.button else {
                return
            }

            self.showPopover(from: button)
        }
    }

    private func schedulePopoverVerticalPositionUpdate() {
        positionPopoverWindowNearStatusItem()

        Task { @MainActor [weak self] in
            await Task.yield()
            self?.positionPopoverWindowNearStatusItem()
        }
    }

    private func positionPopoverWindowNearStatusItem() {
        guard popover.isShown, let button = statusItem.button else {
            return
        }

        positionPopoverWindow(near: button)
    }

    private func positionPopoverWindow(near button: NSStatusBarButton) {
        guard
            let popoverWindow = popover.contentViewController?.view.window,
            let buttonWindow = button.window
        else {
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame

        var frame = popoverWindow.frame
        frame.origin.y = buttonFrameOnScreen.minY - Layout.menuBarPopoverGap - frame.height

        if let screenFrame {
            let minimumY = screenFrame.minY + Layout.menuBarPopoverGap
            let maximumY = screenFrame.maxY - Layout.menuBarPopoverGap - frame.height
            frame.origin.y = min(max(frame.origin.y, minimumY), maximumY)
        }

        popoverWindow.setFrame(frame, display: true)
    }

    private func anchorRect(in button: NSStatusBarButton) -> NSRect {
        guard
            let imageRect = (button.cell as? NSButtonCell)?.imageRect(forBounds: button.bounds),
            !imageRect.isEmpty
        else {
            return button.bounds
        }

        return imageRect
    }
}
