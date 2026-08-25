import Foundation
import PomodoroFormula

/// A named, fully independent set of overrun-curve constants — lets
/// different task types (e.g. "Deep work" vs "Quick task") react to
/// overrun completely differently, not just start from a different number.
public struct Preset: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var constants: AdjustmentFormula.Constants

    public init(id: UUID = UUID(), name: String, constants: AdjustmentFormula.Constants) {
        self.id = id
        self.name = name
        self.constants = constants
    }
}
