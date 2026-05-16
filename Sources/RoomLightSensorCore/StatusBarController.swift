import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let monitor: LuxMonitor
    private let notificationManager: NotificationManager
    private let launchAtLoginManager: LaunchAtLoginManager
    private let focusCoordinator = SettingsViewFocusCoordinator()
    private var cancellables = Set<AnyCancellable>()
    private var popoverAnchorWindow: NSWindow?
    private var popoverClickMonitor: Any?

    init(
        settings: SettingsStore,
        monitor: LuxMonitor,
        notificationManager: NotificationManager,
        launchAtLoginManager: LaunchAtLoginManager
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.settings = settings
        self.monitor = monitor
        self.notificationManager = notificationManager
        self.launchAtLoginManager = launchAtLoginManager
        super.init()

        configureStatusItem()
        configurePopover()
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

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        configurePopoverContent()
    }

    private func configurePopoverContent() {
        let hostingController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                monitor: monitor,
                notificationManager: notificationManager,
                launchAtLoginManager: launchAtLoginManager,
                focusCoordinator: focusCoordinator
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
        configurePopoverContent()

        if let anchorWindow = makePopoverAnchorWindow(from: button),
           let anchorView = anchorWindow.contentView {
            popoverAnchorWindow = anchorWindow
            anchorWindow.orderFrontRegardless()
            popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        installPopoverClickMonitor()
        activatePopoverWindow()
        clearPopoverFocusAfterLayout()
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

    private func installPopoverClickMonitor() {
        guard popoverClickMonitor == nil else {
            return
        }

        popoverClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self,
                  self.popover.isShown,
                  let popoverWindow = self.popover.contentViewController?.view.window,
                  event.window == popoverWindow else {
                return event
            }

            if !self.eventTargetsEditableTextField(event, in: popoverWindow) {
                self.clearPopoverFocus()
            }

            return event
        }
    }

    private func removePopoverClickMonitor() {
        if let popoverClickMonitor {
            NSEvent.removeMonitor(popoverClickMonitor)
            self.popoverClickMonitor = nil
        }
    }

    private func eventTargetsEditableTextField(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard let contentView = window.contentView else {
            return false
        }

        let location = contentView.convert(event.locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(location) else {
            return false
        }

        return hitView.hasEditableTextFieldAncestor
    }

    private func clearPopoverFocus() {
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        focusCoordinator.clearFocus()
    }

    private func clearPopoverFocusAfterLayout() {
        Task { @MainActor [weak self] in
            self?.activatePopoverWindow()
            self?.clearPopoverFocus()
            await Task.yield()
            self?.activatePopoverWindow()
            self?.clearPopoverFocus()
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard self?.popover.isShown == true else {
                return
            }
            self?.clearPopoverFocus()
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        clearPopoverFocusAfterLayout()
    }

    func popoverWillClose(_ notification: Notification) {
        clearPopoverFocus()
    }

    func popoverDidClose(_ notification: Notification) {
        removePopoverClickMonitor()
        popoverAnchorWindow?.orderOut(nil)
        popoverAnchorWindow = nil
    }
}

private extension NSView {
    var hasEditableTextFieldAncestor: Bool {
        if let textField = self as? NSTextField, textField.isEditable {
            return true
        }

        return superview?.hasEditableTextFieldAncestor ?? false
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
