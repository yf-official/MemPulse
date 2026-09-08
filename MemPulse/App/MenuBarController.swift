import AppKit
import Combine
import CoreText
import SwiftUI

final class MenuBarController: NSObject, NSPopoverDelegate {
    private static let statusItemName = "MemPulse.StatusItem.v1"

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model: AppModel
    private let openMainWindow: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var renderedPercentage: Int?
    private var renderedPressure: MemoryPressureLevel?

    init(model: AppModel, openMainWindow: @escaping () -> Void) {
        self.model = model
        self.openMainWindow = openMainWindow
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        // Assign the stable identity before the status button is requested.
        // Otherwise AppKit can classify it as the unnamed "Item-0", which may
        // retain a hidden state from an earlier development build.
        let visibilityKey = "NSStatusItem VisibleCC \(Self.statusItemName)"
        let hasSavedVisibility = UserDefaults.standard.object(forKey: visibilityKey) != nil
        statusItem.autosaveName = Self.statusItemName
        // On macOS 26 a newly registered app can inherit a stale hidden
        // Control Center record from another development bundle. Choose the
        // expected first-launch default once, while still respecting every
        // subsequent choice made by the user in System Settings.
        if !hasSavedVisibility {
            statusItem.isVisible = true
        }
        configureStatusItem()
        configurePopover()
        bindModel()

    }

    deinit {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        statusItem.behavior = []
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.alignment = .center
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("MemPulse RAM monitor")
        updateStatusImage(percentage: 0, pressure: .unknown)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 344, height: 520)
        let controller = NSHostingController(
            rootView: PopoverView(model: model, openMainWindow: { [weak self] in
                self?.popover.performClose(nil)
                self?.openMainWindow()
            })
        )
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        popover.contentViewController = controller
    }

    private func bindModel() {
        model.$memoryStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.updateStatusImage(
                    percentage: Int(stats.usagePercentage.rounded()),
                    pressure: stats.pressure
                )
            }
            .store(in: &cancellables)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refreshNow()
            popover.contentViewController?.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.popover.performClose(nil)
            }
        }
    }

    @objc private func statusItemClicked() {
        togglePopover()
    }

    private func updateStatusImage(percentage: Int, pressure: MemoryPressureLevel) {
        let value = min(max(percentage, 0), 100)
        guard value != renderedPercentage || pressure != renderedPressure else { return }
        renderedPercentage = value
        renderedPressure = pressure
        let color: NSColor
        switch pressure {
        case .critical: color = .systemRed
        case .warning: color = .systemOrange
        case .normal, .unknown: color = .labelColor
        }
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = makeStatusImage(
            value: value,
            color: color,
            isTemplate: pressure == .normal || pressure == .unknown
        )
    }

    private func makeStatusImage(value: Int, color: NSColor, isTemplate: Bool) -> NSImage {
        let imageSize = NSSize(width: 28, height: 22)
        let values = ["\(value)%", "RAM"]
        let image = NSImage(size: imageSize, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
            ]
            let slotHeight = imageSize.height / CGFloat(values.count)

            for (index, value) in values.enumerated() {
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: attributes))
                let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
                let slotCenterY = imageSize.height - slotHeight * (CGFloat(index) + 0.5)
                context.textPosition = CGPoint(
                    x: (imageSize.width - bounds.width) / 2 - bounds.minX,
                    y: slotCenterY - bounds.midY
                )
                CTLineDraw(line, context)
            }
            return true
        }
        image.isTemplate = isTemplate
        return image
    }

    var diagnosticDescription: String {
        let button = statusItem.button
        let frame = button?.window?.frame.debugDescription ?? "nil"
        let buttonFrame = button?.frame.debugDescription ?? "nil"
        return "visible=\(statusItem.isVisible) length=\(statusItem.length) hidden=\(button?.isHidden ?? true) title=\(button?.title ?? "nil") button=\(buttonFrame) window=\(frame)"
    }

    func popoverDidClose(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
