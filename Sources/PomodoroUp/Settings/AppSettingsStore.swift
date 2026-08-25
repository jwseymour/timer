import Foundation
import Observation
import PomodoroFormula

/// UserDefaults-backed store for named presets, each carrying its own full
/// set of target/break/formula constants.
///
/// A plain observable class (not `@AppStorage`) so it can be read from
/// non-View code (`TimerEngine`'s constants provider) as well as bound to
/// in SwiftUI views.
@Observable
public final class AppSettingsStore {
    private enum Keys {
        static let presets = "settings.presets.v1"
        static let selectedPresetID = "settings.selectedPresetID.v1"

        // Legacy single-preset keys from before presets existed. Only ever
        // read once, at first launch, to migrate a user's existing tuned
        // values into the seeded first preset instead of silently
        // discarding them. Left unused afterward — not cleaned up, keeps
        // migration reversible.
        static let legacyTargetMinutes = "settings.targetMinutes"
        static let legacyBreakMinutes = "settings.breakMinutes"
        static let legacyKt = "settings.kt"
        static let legacyP = "settings.p"
        static let legacyBreakCapBonus = "settings.breakCapBonus"
        static let legacyQ = "settings.q"
    }

    private let defaults: UserDefaults

    public private(set) var presets: [Preset] {
        didSet { persistPresets() }
    }
    public private(set) var selectedPresetID: Preset.ID {
        didSet { defaults.set(selectedPresetID.uuidString, forKey: Keys.selectedPresetID) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Computed into locals first: the @Observable macro's generated
        // accessors require every stored property initialized before self
        // can be read again, so `presets` can't be read back via `self`
        // while still resolving `selectedPresetID` below.
        let resolvedPresets: [Preset]
        if let data = defaults.data(forKey: Keys.presets),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data),
           !decoded.isEmpty {
            resolvedPresets = decoded
        } else {
            resolvedPresets = [Self.seedPreset(from: defaults)]
        }

        let resolvedSelectedID: Preset.ID
        if let idString = defaults.string(forKey: Keys.selectedPresetID),
           let id = UUID(uuidString: idString),
           resolvedPresets.contains(where: { $0.id == id }) {
            resolvedSelectedID = id
        } else {
            resolvedSelectedID = resolvedPresets[0].id
        }

        presets = resolvedPresets
        selectedPresetID = resolvedSelectedID
    }

    private static func seedPreset(from defaults: UserDefaults) -> Preset {
        let fallback = AdjustmentFormula.Constants.defaults
        let hasLegacyValues = defaults.object(forKey: Keys.legacyTargetMinutes) != nil
        guard hasLegacyValues else {
            return Preset(name: "Default", constants: fallback)
        }
        let constants = AdjustmentFormula.Constants(
            targetMinutes: defaults.object(forKey: Keys.legacyTargetMinutes) as? Double ?? fallback.targetMinutes,
            breakMinutes: defaults.object(forKey: Keys.legacyBreakMinutes) as? Double ?? fallback.breakMinutes,
            kt: defaults.object(forKey: Keys.legacyKt) as? Double ?? fallback.kt,
            p: defaults.object(forKey: Keys.legacyP) as? Double ?? fallback.p,
            breakCapBonus: defaults.object(forKey: Keys.legacyBreakCapBonus) as? Double ?? fallback.breakCapBonus,
            q: defaults.object(forKey: Keys.legacyQ) as? Double ?? fallback.q
        )
        return Preset(name: "Default", constants: constants)
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Keys.presets)
        }
    }

    public var selectedPreset: Preset {
        presets.first { $0.id == selectedPresetID } ?? presets[0]
    }

    /// A snapshot suitable for `AdjustmentFormula.compute` / `TimerEngine`.
    public var constants: AdjustmentFormula.Constants {
        selectedPreset.constants
    }

    public func selectPreset(id: Preset.ID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        selectedPresetID = id
    }

    @discardableResult
    public func addPreset(named name: String, constants: AdjustmentFormula.Constants = .defaults) -> Preset {
        let preset = Preset(name: name, constants: constants)
        presets.append(preset)
        return preset
    }

    @discardableResult
    public func duplicatePreset(id: Preset.ID) -> Preset? {
        guard let source = presets.first(where: { $0.id == id }) else { return nil }
        let copy = Preset(name: "Copy of \(source.name)", constants: source.constants)
        presets.append(copy)
        return copy
    }

    public func updatePreset(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
    }

    public func deletePreset(id: Preset.ID) {
        guard presets.count > 1 else { return }
        presets.removeAll { $0.id == id }
        if selectedPresetID == id {
            selectedPresetID = presets[0].id
        }
    }
}
