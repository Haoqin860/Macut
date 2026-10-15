import AppKit
import Carbon
import SwiftUI

final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard identifier.signature == 0x4D435554 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().onPress?()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        var next: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x4D435554, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier,
                                        GetApplicationEventTarget(), 0, &next)
        guard status == noErr else { return false }
        if let reference { UnregisterEventHotKey(reference) }
        reference = next
        return true
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}

struct KeyRecorder: NSViewRepresentable {
    var isRecording: Bool
    var onShortcut: (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onShortcut = onShortcut
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.onShortcut = onShortcut
        if isRecording { DispatchQueue.main.async { view.window?.makeFirstResponder(view) } }
    }

    final class RecorderView: NSView {
        var onShortcut: ((Shortcut?) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { onShortcut?(nil); return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.intersection([.command, .control, .option]).isEmpty else { NSSound.beep(); return }
            var modifiers: UInt32 = 0
            var label = ""
            if flags.contains(.control) { modifiers |= UInt32(controlKey); label += "⌃" }
            if flags.contains(.option) { modifiers |= UInt32(optionKey); label += "⌥" }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey); label += "⇧" }
            if flags.contains(.command) { modifiers |= UInt32(cmdKey); label += "⌘" }
            let special: [UInt16: String] = [49: "Space", 36: "↩", 48: "⇥", 123: "←", 124: "→", 125: "↓", 126: "↑"]
            guard let key = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { return }
            label += key
            onShortcut?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label))
        }
    }
}
