import Cocoa
import SwiftUI
import UserNotifications
import Combine

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store = WaterStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notifications permission
        NotificationManager.shared.requestAuthorization()

        // Setup Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 490)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView(store: store))
        self.popover = popover

        // Setup Menu Bar Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusItem()

        // Subscribe to store updates to keep menu bar updated
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)

        // Monitor clicks outside popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let currentEvent = NSApp.currentEvent
        if currentEvent?.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let appTitleItem = NSMenuItem(title: "AquaFlow", action: nil, keyEquivalent: "")
        appTitleItem.attributedTitle = NSAttributedString(
            string: "AquaFlow - Hydration Tracker",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(appTitleItem)

        let statusText = store.isReminderPaused ? "Reminders: Paused" : "Next reminder: \(store.formattedCountdown)"
        let countdownItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        countdownItem.isEnabled = false
        menu.addItem(countdownItem)

        let intakeText = "Today: \(store.currentIntake)/\(store.dailyGoal) ml (\(Int(store.progressPercent * 100))%)"
        let intakeItem = NSMenuItem(title: intakeText, action: nil, keyEquivalent: "")
        intakeItem.isEnabled = false
        menu.addItem(intakeItem)

        menu.addItem(NSMenuItem.separator())

        let add250Item = NSMenuItem(title: "💧 Drink Glass (250 ml)", action: #selector(menuAdd250), keyEquivalent: "")
        add250Item.target = self
        menu.addItem(add250Item)

        let add500Item = NSMenuItem(title: "🥛 Drink Bottle (500 ml)", action: #selector(menuAdd500), keyEquivalent: "")
        add500Item.target = self
        menu.addItem(add500Item)

        let snoozeItem = NSMenuItem(title: "⏳ Snooze 10 Minutes", action: #selector(menuSnooze10), keyEquivalent: "")
        snoozeItem.target = self
        menu.addItem(snoozeItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open AquaFlow...", action: #selector(menuOpenApp), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit AquaFlow", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // restore button action
    }

    @objc private func menuAdd250() {
        store.addWater(amount: 250)
    }

    @objc private func menuAdd500() {
        store.addWater(amount: 500)
    }

    @objc private func menuSnooze10() {
        store.snooze(minutes: 10)
    }

    @objc private func menuOpenApp() {
        if let button = statusItem.button {
            showPopover(button)
        }
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        // Icon configuration
        let iconName = store.progressPercent >= 1.0 ? "checkmark.circle.fill" : "drop.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: "AquaFlow")?.withSymbolConfiguration(config) {
            img.isTemplate = true
            button.image = img
            button.imagePosition = .imageLeft
        }

        switch store.menuBarMode {
        case .iconOnly:
            button.title = ""
        case .iconAndPercent:
            let pct = Int(store.progressPercent * 100)
            button.title = " \(pct)%"
        case .iconAndAmount:
            button.title = " \(store.currentIntake)ml"
        }
    }
}
