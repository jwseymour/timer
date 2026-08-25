import AppKit
import IOKit.hid

/// Thin wrapper around the Input Monitoring TCC category — the correct
/// permission for passively observing global keyboard input (what
/// `GlobalHotkeyMonitor` does). Distinct from Accessibility, which governs
/// synthesizing/posting events, not just observing them.
public enum InputMonitoringPermission {
    public static var isGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Triggers the system permission prompt the first time it's called for
    /// this app. Returns immediately with the access state at call time —
    /// on first-ever call this reflects "not yet decided," not the user's
    /// eventual choice, so callers should re-check `isGranted` later (e.g.
    /// `.onAppear`) rather than trust this return value alone.
    @discardableResult
    public static func request() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    public static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}
