import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var model: AppModel?
    private var previewWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("TZC is a menu-bar utility")
        ProcessInfo.processInfo.disableSuddenTermination()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--unregister-login") {
            LoginItemManager.disable()
            NSApplication.shared.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--ui-preview") {
            showPreviewWindow()
            return
        }

        let model = AppModel()
        self.model = model

        installStatusItem(using: model)
        LoginItemManager.enable()

        if CommandLine.arguments.contains("--open-panel") {
            DispatchQueue.main.async { [weak self] in
                self?.showPanelFromStatusItem()
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            showPanelFromStatusItem()
        }
        return false
    }

    private func installStatusItem(using model: AppModel) {
        let hostingController = PanelHostingController(
            rootView: ContentView()
                .environmentObject(model)
        )
        hostingController.sizeDidChange = { [weak self] size in
            self?.resizePanel(to: size)
        }

        let panel = MenuBarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 581),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentViewController = hostingController

        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 16
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "TZC.StatusItem.v1"
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.image = makeStatusIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "TZC"
            button.setAccessibilityLabel("TZC")
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        self.panel = panel
        self.statusItem = statusItem
        NSLog("TZC status item installed")
    }

    @objc
    private func togglePanel(_ sender: Any?) {
        guard let panel else { return }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanelFromStatusItem()
        }
    }

    private func showPanelFromStatusItem() {
        guard let statusButton = statusItem?.button,
              let panel else {
            return
        }
        showPanel(panel, anchoredTo: statusButton)
    }

    private func showPanel(_ panel: NSPanel, anchoredTo statusButton: NSStatusBarButton) {
        guard let statusWindow = statusButton.window else { return }

        let buttonRectInWindow = statusButton.convert(statusButton.bounds, to: nil)
        let buttonRectOnScreen = statusWindow.convertToScreen(buttonRectInWindow)
        let screenFrame = (statusWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 300, height: 581)
        let panelSize = panel.frame.size
        let horizontalMargin: CGFloat = 8

        var originX = buttonRectOnScreen.midX - panelSize.width / 2
        originX = max(screenFrame.minX + horizontalMargin, originX)
        originX = min(screenFrame.maxX - panelSize.width - horizontalMargin, originX)

        var originY = buttonRectOnScreen.minY - panelSize.height - 4
        if originY < screenFrame.minY + horizontalMargin {
            originY = buttonRectOnScreen.maxY + 4
        }

        panel.setFrameOrigin(NSPoint(x: originX.rounded(), y: originY.rounded()))
        panel.makeKeyAndOrderFront(nil)
        installDismissMonitors()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        removeDismissMonitors()
    }

    private func resizePanel(to proposedSize: NSSize) {
        guard proposedSize.width > 0,
              proposedSize.height > 0,
              proposedSize.width.isFinite,
              proposedSize.height.isFinite,
              let panel else {
            return
        }

        let size = NSSize(
            width: proposedSize.width.rounded(),
            height: proposedSize.height.rounded()
        )
        guard panel.frame.size != size else { return }

        if panel.isVisible {
            let topEdge = panel.frame.maxY
            panel.setFrame(
                NSRect(
                    x: panel.frame.minX,
                    y: topEdge - size.height,
                    width: size.width,
                    height: size.height
                ),
                display: true,
                animate: true
            )
        } else {
            panel.setContentSize(size)
        }
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor in
                    self?.hidePanel()
                }
                return nil
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hidePanel()
            }
        }
    }

    private func removeDismissMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.15, dy: 1.15))
            ring.lineWidth = 1.35
            ring.stroke()

            NSBezierPath(ovalIn: NSRect(x: 7.05, y: 10.55, width: 1.9, height: 1.9)).fill()

            let tickX: [CGFloat] = [3.55, 5.75, 8, 10.25, 12.45]
            let tickHeights: [CGFloat] = [3.8, 6, 4.7, 6, 3.8]

            for (x, height) in zip(tickX, tickHeights) {
                let tick = NSBezierPath()
                tick.move(to: NSPoint(x: x, y: 2.8))
                tick.line(to: NSPoint(x: x, y: 2.8 + height))
                tick.lineWidth = 1.35
                tick.lineCapStyle = .round
                tick.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    private func showPreviewWindow() {
        let model = AppModel()
        let content = ContentView()
            .environmentObject(model)

        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 581),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TZC Preview"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()

        self.model = model
        previewWindow = window
    }
}

@MainActor
private final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class PanelHostingController<Content: View>: NSHostingController<Content> {
    var sizeDidChange: ((NSSize) -> Void)?
    private var lastReportedSize = NSSize.zero

    override func viewDidLayout() {
        super.viewDidLayout()

        let size = view.fittingSize
        guard size != lastReportedSize else { return }

        lastReportedSize = size
        sizeDidChange?(size)
    }
}
