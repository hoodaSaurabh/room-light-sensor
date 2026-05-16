import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let monitor: LuxMonitor
    private var cancellables = Set<AnyCancellable>()
    private var popoverAnchorWindow: NSWindow?

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
        popover.delegate = self
        let hostingController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                monitor: monitor,
                notificationManager: notificationManager,
                launchAtLoginManager: launchAtLoginManager
            )
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
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

        switch status {
        case .unavailable:
            button.title = "No ALS"
        case .failed:
            button.title = "ALS !"
        case .waiting, .reading:
            button.title = showLux ? LuxFormatter.menuBarString(for: lux) : ""
        }

        statusItem.length = button.title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
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
        if let anchorWindow = makePopoverAnchorWindow(from: button),
           let anchorView = anchorWindow.contentView {
            popoverAnchorWindow = anchorWindow
            anchorWindow.orderFrontRegardless()
            popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        activatePopoverWindow()
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.activatePopoverWindow()
        }
    }

    private func makePopoverAnchorWindow(from button: NSStatusBarButton) -> NSWindow? {
        guard let buttonWindow = button.window else {
            return nil
        }

        let anchorFrame = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        let anchorWindow = PopoverAnchorWindow(
            contentRect: anchorFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        anchorWindow.backgroundColor = .clear
        anchorWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        anchorWindow.hasShadow = false
        anchorWindow.ignoresMouseEvents = true
        anchorWindow.isOpaque = false
        anchorWindow.isReleasedWhenClosed = false
        anchorWindow.level = .statusBar
        anchorWindow.contentView = NSView(frame: NSRect(origin: .zero, size: anchorFrame.size))

        return anchorWindow
    }

    private func activatePopoverWindow() {
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popoverAnchorWindow?.orderOut(nil)
        popoverAnchorWindow = nil
    }
}

private final class PopoverAnchorWindow: NSWindow {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
