import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private enum Layout {
        static let menuBarPopoverGap: CGFloat = 6
    }

    private struct StatusItemState {
        let title: String
        let length: CGFloat
    }

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let monitor: LuxMonitor
    private var cancellables = Set<AnyCancellable>()
    private var deferredStatusItemState: StatusItemState?

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
        popover.delegate = self
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
        let state = statusItemState(lux: lux, status: status, showLux: showLux)

        if popover.isShown {
            deferredStatusItemState = state
            return
        }

        applyStatusItemState(state)
    }

    private func statusItemState(lux: Double?, status: SensorStatus, showLux: Bool) -> StatusItemState {
        let title: String
        switch status {
        case .unavailable:
            title = "No ALS"
        case .failed:
            title = "ALS !"
        case .waiting, .reading:
            title = showLux ? LuxFormatter.menuBarString(for: lux) : ""
        }

        return StatusItemState(
            title: title,
            length: title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        )
    }

    private func applyStatusItemState(_ state: StatusItemState) {
        guard let button = statusItem.button else {
            return
        }

        button.title = state.title
        statusItem.length = state.length
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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        schedulePopoverVerticalPositionUpdate()
        popover.contentViewController?.view.window?.makeKey()
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

        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame

        var frame = popoverWindow.frame

        if let screenFrame {
            frame.origin.y = screenFrame.maxY - Layout.menuBarPopoverGap - frame.height
            let minimumY = screenFrame.minY + Layout.menuBarPopoverGap
            frame.origin.y = max(frame.origin.y, minimumY)
        }

        popoverWindow.setFrame(frame, display: true)
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        guard let deferredStatusItemState else {
            return
        }

        self.deferredStatusItemState = nil
        applyStatusItemState(deferredStatusItemState)
    }
}
