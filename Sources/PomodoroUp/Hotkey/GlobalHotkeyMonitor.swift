import AppKit
import Observation

/// Passively observes a single global key combo system-wide (does not
/// consume/block the key for other apps) and calls `handler` when it fires.
/// Requires the user to have granted Input Monitoring — see
/// `InputMonitoringPermission`. Before that grant, `start()` still
/// "succeeds" at the API level but simply never delivers events; the app
/// must remain fully usable without it.
@Observable
public final class GlobalHotkeyMonitor {
    public struct KeyCombo: Equatable, Sendable {
        public let keyCode: UInt16
        public let modifiers: NSEvent.ModifierFlags

        public init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }

    /// Control+Option+Space — avoids Spotlight (⌘Space) and other common
    /// system/app chords. Fixed for v1; a rebinding UI is a natural v2.
    public static let defaultCombo = KeyCombo(keyCode: 49, modifiers: [.control, .option])

    private static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .command, .shift]

    private let combo: KeyCombo
    private let handler: () -> Void
    private var monitor: Any?

    public init(combo: KeyCombo = GlobalHotkeyMonitor.defaultCombo, handler: @escaping () -> Void) {
        self.combo = combo
        self.handler = handler
    }

    deinit {
        stop()
    }

    public var isRunning: Bool { monitor != nil }

    public func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [combo, handler] event in
            let pressedModifiers = event.modifierFlags.intersection(Self.relevantModifiers)
            if event.keyCode == combo.keyCode && pressedModifiers == combo.modifiers {
                handler()
            }
        }
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
