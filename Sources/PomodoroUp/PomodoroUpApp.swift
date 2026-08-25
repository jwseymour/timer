import SwiftUI
import SwiftData
import PomodoroFormula

@main
struct PomodoroUpApp: App {
    @State private var settingsStore: AppSettingsStore
    @State private var engine: TimerEngine
    @State private var hotkeyMonitor: GlobalHotkeyMonitor
    private let modelContainer: ModelContainer

    init() {
        let store = AppSettingsStore()

        let container: ModelContainer
        do {
            // An explicit store URL avoids SwiftData's default behavior of
            // deriving a store name from the app bundle, which doesn't
            // exist when running as a bare executable (no Info.plist).
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let storeDirectory = appSupport.appendingPathComponent("PomodoroUp", isDirectory: true)
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let storeURL = storeDirectory.appendingPathComponent("PomodoroUp.store")
            let configuration = ModelConfiguration("PomodoroUp", url: storeURL)
            container = try ModelContainer(for: WorkSession.self, configurations: configuration)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        let timerEngine = TimerEngine(constantsProvider: { store.constants })
        let player = SoundPlayer()
        let context = container.mainContext

        timerEngine.onTargetCrossed = { player.playTargetReached() }
        timerEngine.onBreakEnded = { player.playBreakEnded() }
        timerEngine.onSessionCompleted = { record in
            context.insert(WorkSession(record: record))
        }
        timerEngine.startAutoTicking()

        let monitor = GlobalHotkeyMonitor { [weak timerEngine] in
            timerEngine?.performPrimaryAction()
        }
        if InputMonitoringPermission.isGranted {
            monitor.start()
        }

        _settingsStore = State(initialValue: store)
        _engine = State(initialValue: timerEngine)
        _hotkeyMonitor = State(initialValue: monitor)
        modelContainer = container
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(engine: engine)
                .environment(settingsStore)
        } label: {
            MenuBarLabelView(engine: engine)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)

        Window("Timer", id: WindowIDs.mainTimer) {
            MainTimerView()
        }
        .environment(engine)
        .environment(settingsStore)

        Window("History", id: WindowIDs.history) {
            HistoryView()
        }
        .modelContainer(modelContainer)

        Settings {
            AdvancedSettingsView()
        }
        .environment(settingsStore)
        .environment(hotkeyMonitor)
    }
}
