import Foundation

/// Plain data describing a completed work session, handed out by
/// `TimerEngine` so callers can persist it however they like (SwiftData,
/// logging, etc.) without the engine itself depending on a persistence
/// framework.
public struct WorkSessionRecord: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let baseTargetMinutes: Double
    public let actualWorkSeconds: Double
    public let overrunSeconds: Double
    public let baseBreakMinutes: Double
    public let adjustedBreakMinutes: Double
    public let nextTargetMinutes: Double
}
