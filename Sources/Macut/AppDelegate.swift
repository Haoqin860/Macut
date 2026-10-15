import AppKit
import ClipboardCore
import Combine
import SwiftUI

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ClipboardPanel!
    private var settingsWindow: NSWindow?
    private var imageWindow: NSWindow?
    private var hotKey: HotKey!
    private var model: AppModel!
    private var preferences: Preferences!
    private var targetApp: NSRunningApplication?
    private var keyboardMonitor: Any?
    private var mouseMonitor: Any?
    private var previewSubscription: AnyCancellable?
    private var pausedSubscription: AnyCancellable?
    private var initialShortcutError: String?
    private var pasteInFlight = false
    private var isDemo = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let id = Bundle.main.bundleIdentifier ?? "app.macut.Macut"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { $0.processIdentifier != getpid() }
        if !others.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(.init("app.macut.show"), object: nil)
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        installEditMenu()
        isDemo = CommandLine.arguments.contains("--demo")
        preferences = Preferences(defaults: isDemo ? UserDefaults(suiteName: "app.macut.demo")! : .standard)
        var directory: URL?
        if isDemo {
            directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Macut-Demo-\(getpid())")
            try? DemoData.seed(at: directory!)
        }
        model = AppModel(preferences: preferences, directory: directory, monitoringEnabled: !isDemo)
        model.onPasteRequested = { [weak self] in self?.paste($0, plainText: $1) }
        model.onCloseRequested = { [weak self] in self?.hidePanel() }
        model.onSettingsRequested = { [weak self] in self?.showSettings() }
        model.onPreviewRequested = { [weak self] in self?.showImagePreview() }
        makePanel()
        makeStatusItem()
        hotKey = HotKey()
        hotKey.onPress = { [weak self] in self?.togglePanel() }
        if !hotKey.register(preferences.shortcut) {
            initialShortcutError = "快捷键 \(preferences.shortcut.label) 已被占用。可先通过菜单栏打开，在设置中更换。"
        }
        installEventMonitors()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showFromNotification),
                                                              name: .init("app.macut.show"), object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep),
                                                           name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPermission),
                                                name: NSApplication.didBecomeActiveNotification, object: nil)
        previewSubscription = preferences.$showPreview.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizePanel() }
        }
        pausedSubscription = model.$paused.sink { [weak self] paused in
            self?.statusItem.button?.appearsDisabled = paused
        }
        showPanel()
        if let initialShortcutError { model.notify(initialShortcutError, persistent: true) }
    }

    private func makePanel() {
        panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: 840, height: 566),
                               styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                               backing: .buffered, defer: false)
        panel.title = "Macut 剪贴板"
        panel.identifier = .init("macut-clipboard")
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PanelView(model: model, preferences: preferences))
        resizePanel()
    }

    private func resizePanel() {
        let oldCenter = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let screen = panel.screen ?? activeScreen()
        let width = min(preferences.showPreview ? 840.0 : 445.0, screen.visibleFrame.width - 40)
        let height = min(566.0, screen.visibleFrame.height - 60)
        var rect = NSRect(x: oldCenter.x - width / 2, y: oldCenter.y - height / 2, width: width, height: height)
        rect.origin.x = min(max(rect.minX, screen.visibleFrame.minX + 20), screen.visibleFrame.maxX - width - 20)
        panel.setFrame(rect, display: panel.isVisible)
    }

    private func activeScreen() -> NSScreen {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "Macut 剪贴板")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Macut · \(preferences.shortcut.label)\n右键打开菜单，⌥ 点击暂停记录"
        }
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showStatusMenu(); return }
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true { model.paused.toggle(); return }
        togglePanel()
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开剪贴板  \(preferences.shortcut.label)", action: #selector(showFromNotification), keyEquivalent: "")
        menu.addItem(withTitle: model.paused ? "继续记录" : "暂停记录", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(settingsAction), keyEquivalent: ",")
        menu.addItem(withTitle: "退出 Macut", action: #selector(quitAction), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePause() { model.paused.toggle() }
    @objc private func settingsAction() { showSettings() }
    @objc private func quitAction() { NSApp.terminate(nil) }
    @objc private func showFromNotification() { showPanel() }
    @objc private func willSleep() { hidePanel() }
    @objc private func refreshPermission() { model?.accessibilityGranted = AXIsProcessTrusted() }

    private func togglePanel() { panel.isVisible ? hidePanel() : showPanel() }

    private func showPanel() {
        guard !pasteInFlight else { return }
        if panel.isVisible { panel.makeKey(); return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != getpid() { targetApp = frontmost }
        model.query = ""
        model.filter = .all
        model.selectedID = model.visibleRecords.first?.id
        model.panelSession = UUID()
        model.accessibilityGranted = AXIsProcessTrusted()
        let screen = activeScreen().visibleFrame
        resizePanel()
        let y = min(screen.maxY - panel.frame.height - 24, screen.midY - panel.frame.height / 2 + 65)
        panel.setFrameOrigin(NSPoint(x: screen.midX - panel.frame.width / 2, y: max(screen.minY + 24, y)))
        panel.orderFrontRegardless()
        panel.makeKey()
        // Reuse the SwiftUI search field editor on every invocation.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let field = self.findSearchField(in: self.panel.contentView) { self.panel.makeFirstResponder(field) }
        }
    }

    private func findSearchField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable { return field }
        for child in view.subviews {
            if let field = findSearchField(in: child) { return field }
        }
        return nil
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        imageWindow?.orderOut(nil)
    }

    private func installEventMonitors() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window !== self.panel && event.window !== self.imageWindow { self.hidePanel() }
                return event
            }
            if event.window === self.imageWindow && (event.keyCode == 53 || event.keyCode == 49) {
                self.imageWindow?.orderOut(nil)
                self.panel.makeKey()
                return nil
            }
            guard event.window === self.panel else { return event }
            // Never consume Return, Space, or arrows while the input method is composing text.
            if let editor = self.panel.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            switch event.keyCode {
            case 53: self.hidePanel(); return nil
            case 125 where flags.isEmpty: self.model.moveSelection(1); return nil
            case 126 where flags.isEmpty: self.model.moveSelection(-1); return nil
            case 36, 76:
                if flags.isEmpty || flags == .command {
                    let kind = self.model.selectedRecord?.kind
                    if flags == .command && (kind == .image || kind == .files) { NSSound.beep(); return nil }
                    self.model.pasteSelected(plainText: flags == .command)
                    return nil
                }
            case 48 where flags.isEmpty || flags == .shift:
                let index = ClipFilter.allCases.firstIndex(of: self.model.filter) ?? 0
                self.model.selectFilter(index + (flags == .shift ? -1 : 1)); return nil
            case 49 where flags.isEmpty && self.model.query.isEmpty && self.model.selectedRecord?.hasImagePreview == true:
                self.showImagePreview(); return nil
            default: break
            }
            if flags == .command, let char = event.charactersIgnoringModifiers?.lowercased() {
                if char == "," { self.showSettings(); return nil }
                if char == "p", let record = self.model.selectedRecord { self.model.toggleFavorite(record); return nil }
                if char == "f", let field = self.findSearchField(in: self.panel.contentView) {
                    self.panel.makeFirstResponder(field); return nil
                }
                if char == "\\" { self.preferences.showPreview.toggle(); return nil }
                if let number = Int(char), (1...9).contains(number), self.model.visibleRecords.count >= number {
                    self.model.selectedID = self.model.visibleRecords[number - 1].id
                    self.model.pasteSelected(); return nil
                }
                if event.keyCode == 51, let record = self.model.selectedRecord { self.model.delete(record); return nil }
            }
            return event
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            let point = NSEvent.mouseLocation
            if !self.panel.frame.contains(point) && self.imageWindow?.frame.contains(point) != true { self.hidePanel() }
        }
    }

    private func paste(_ record: ClipRecord, plainText: Bool) {
        guard !pasteInFlight else { return }
        pasteInFlight = true
        let destination = targetApp
        let panelSession = model.panelSession
        model.preparePaste(record, plainText: plainText) { [weak self] result in
            guard let self else { return }
            defer { self.pasteInFlight = false }
            guard self.panel.isVisible, self.model.panelSession == panelSession else { return }
            switch result {
            case .failure(let error): self.model.notify("内容读取失败：\(error.localizedDescription)")
            case .success(let snapshot):
                let board = NSPasteboard.general
                let items = snapshot.map { reps -> NSPasteboardItem in
                    let item = NSPasteboardItem()
                    for rep in reps { item.setData(rep.data, forType: .init(rep.type)) }
                    item.setString("1", forType: AppModel.ownMarker)
                    return item
                }
                board.clearContents()
                guard board.writeObjects(items) else { self.model.notify("无法写入系统剪贴板，请重试"); return }
                self.model.markInternalCopy()
                self.model.mutateStore { try $0.touch(record.id) }
                let canPaste = AXIsProcessTrusted()
                self.model.accessibilityGranted = canPaste
                self.hidePanel()
                if let destination, !destination.isTerminated {
                    destination.activate(options: [])
                }
                if self.preferences.autoPaste && canPaste, let destination {
                    self.sendPasteWhenReady(to: destination, expectedChangeCount: board.changeCount)
                } else {
                    self.showCopiedFeedback()
                }
            }
        }
    }

    private func sendPasteWhenReady(to destination: NSRunningApplication, expectedChangeCount: Int, attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self, !destination.isTerminated, !self.panel.isVisible,
                  NSPasteboard.general.changeCount == expectedChangeCount else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != destination.processIdentifier {
                if attempt < 6 { self.sendPasteWhenReady(to: destination, expectedChangeCount: expectedChangeCount, attempt: attempt + 1) }
                else { self.showCopiedFeedback() }
                return
            }
            guard let source = CGEventSource(stateID: .combinedSessionState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return }
            down.flags = [.maskCommand]
            up.flags = [.maskCommand]
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    private func showCopiedFeedback() {
        statusItem.button?.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "已复制，请按 Command V 粘贴")
        statusItem.button?.toolTip = "已复制 · 回到原应用按 ⌘V 粘贴"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.statusItem.button?.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "Macut")
        }
    }

    private func showSettings() {
        hidePanel()
        model.accessibilityGranted = AXIsProcessTrusted()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 586, height: 496),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Macut 设置"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences, model: model) { [weak self] shortcut in
                guard let self, self.hotKey.register(shortcut) else { return false }
                self.preferences.shortcut = shortcut
                self.statusItem.button?.toolTip = "Macut · \(shortcut.label)"
                return true
            })
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showImagePreview() {
        guard let record = model.selectedRecord, record.hasImagePreview, let image = model.previewImage else { return }
        if imageWindow == nil {
            let screen = activeScreen().visibleFrame
            let window = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: min(800, screen.width - 80),
                                                             height: min(600, screen.height - 80)),
                                        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.minSize = NSSize(width: 320, height: 240)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            imageWindow = window
        }
        imageWindow?.title = record.title
        // A native image view keeps the preview window's size independent of the image's intrinsic size.
        let imageView = NSImageView(frame: imageWindow?.contentView?.bounds ?? .zero)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = [.width, .height]
        imageWindow?.contentView = imageView
        imageWindow?.center()
        imageWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { model.applyRetention() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(); return true
    }

    private func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let quit = NSMenuItem(title: "退出 Macut", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "编辑")
        for (title, selector, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"),
                                       ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
