import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let monitor = SystemMonitor.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.registerMacPulseDefaults()
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 660)
        popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))

        monitor.onUpdate = { [weak self] in self?.refreshTitle() }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.monitor.rescheduleIfNeeded()
                self?.refreshTitle()
            }
        }
        monitor.start()

        // Debug aid: `MacPulse --show-popover` opens the panel straight away.
        if CommandLine.arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.togglePopover() }
        }
    }

    // MARK: Status item

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Activity Monitor", action: #selector(openActivityMonitor), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit MacPulse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    /// Builds the menu bar text from whichever metrics are switched on in settings.
    private func refreshTitle() {
        let d = UserDefaults.standard
        let fahrenheit = d.bool(forKey: "fahrenheit")
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let title = NSMutableAttributedString()

        func add(symbol: String, _ text: String) {
            if title.length > 0 { title.append(NSAttributedString(string: "  ", attributes: [.font: font])) }
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: -2, width: image.size.width, height: image.size.height)
                title.append(NSAttributedString(attachment: attachment))
            }
            title.append(NSAttributedString(string: " " + text, attributes: [.font: font]))
        }

        if d.bool(forKey: "showCPU") {
            add(symbol: "cpu", pad(Format.percent(monitor.cpu.total), 3))
        }
        if d.bool(forKey: "showMemory") {
            add(symbol: "memorychip", pad(Format.percent(monitor.memory.usedFraction), 3))
        }
        if d.bool(forKey: "showTemperature"), let t = monitor.thermal.headline {
            add(symbol: "thermometer.medium", Format.temperature(t, fahrenheit: fahrenheit))
        }
        if d.bool(forKey: "showBattery"), monitor.battery.present {
            add(symbol: Self.batterySymbol(monitor.battery), "\(monitor.battery.percent)%")
        }
        if d.bool(forKey: "showNetwork") {
            add(symbol: "arrow.down", pad(Format.speed(monitor.network.down, compact: true), 4))
            add(symbol: "arrow.up", pad(Format.speed(monitor.network.up, compact: true), 4))
        }

        if title.length == 0 {
            statusItem.button?.attributedTitle = NSAttributedString()
            statusItem.button?.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "MacPulse")
        } else {
            statusItem.button?.image = nil
            statusItem.button?.attributedTitle = title
        }
    }

    /// Left-pads with figure spaces so the item doesn't jitter as numbers change.
    private func pad(_ s: String, _ width: Int) -> String {
        String(repeating: "\u{2007}", count: max(0, width - s.count)) + s
    }

    private static func batterySymbol(_ b: BatteryStats) -> String {
        if b.isCharging { return "battery.100.bolt" }
        switch b.percent {
        case 88...: return "battery.100"
        case 63...: return "battery.75"
        case 38...: return "battery.50"
        case 13...: return "battery.25"
        default: return "battery.0"
        }
    }
}
