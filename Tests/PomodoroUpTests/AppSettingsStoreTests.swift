import XCTest
@testable import PomodoroUp
import PomodoroFormula

final class AppSettingsStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSeedsOneDefaultPresetOnFirstLaunch() {
        let store = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.selectedPreset.constants, AdjustmentFormula.Constants.defaults)
    }

    func testMigratesLegacyFlatKeysIntoSeededPreset() {
        defaults.set(45.0, forKey: "settings.targetMinutes")
        defaults.set(12.0, forKey: "settings.breakMinutes")
        defaults.set(1.5, forKey: "settings.kt")
        defaults.set(0.5, forKey: "settings.p")
        defaults.set(8.0, forKey: "settings.breakCapBonus")
        defaults.set(0.4, forKey: "settings.q")

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.selectedPreset.constants.targetMinutes, 45)
        XCTAssertEqual(store.selectedPreset.constants.breakMinutes, 12)
        XCTAssertEqual(store.selectedPreset.constants.kt, 1.5)
        XCTAssertEqual(store.selectedPreset.constants.p, 0.5)
        XCTAssertEqual(store.selectedPreset.constants.breakCapBonus, 8)
        XCTAssertEqual(store.selectedPreset.constants.q, 0.4)
    }

    func testAddDuplicateRenameUpdatePersistAcrossInstances() {
        let store1 = AppSettingsStore(defaults: defaults)
        let quickTask = store1.addPreset(named: "Quick Task", constants: .init(targetMinutes: 15, breakMinutes: 3, kt: 1, p: 0.4, breakCapBonus: 3, q: 0.3))
        store1.selectPreset(id: quickTask.id)

        let duplicated = store1.duplicatePreset(id: quickTask.id)
        XCTAssertNotNil(duplicated)
        XCTAssertEqual(duplicated?.name, "Copy of Quick Task")

        var renamed = quickTask
        renamed.name = "Renamed"
        store1.updatePreset(renamed)

        // A second store instance reading the same suite should see everything.
        let store2 = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(store2.presets.count, 3) // Default + Quick Task(renamed) + duplicate
        XCTAssertEqual(store2.selectedPreset.id, quickTask.id)
        XCTAssertEqual(store2.selectedPreset.name, "Renamed")
        XCTAssertTrue(store2.presets.contains { $0.name == "Copy of Quick Task" })
    }

    func testCannotDeleteTheLastPreset() {
        let store = AppSettingsStore(defaults: defaults)
        let onlyID = store.presets[0].id
        store.deletePreset(id: onlyID)
        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.presets[0].id, onlyID)
    }

    func testDeletingSelectedPresetReselectsARemainingOne() {
        let store = AppSettingsStore(defaults: defaults)
        let originalID = store.presets[0].id
        let second = store.addPreset(named: "Second")
        store.selectPreset(id: second.id)

        store.deletePreset(id: second.id)

        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.selectedPresetID, originalID)
    }
}
