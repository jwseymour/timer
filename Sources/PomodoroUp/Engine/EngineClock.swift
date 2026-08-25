import Foundation

/// Abstracts "now" so `TimerEngine` can be driven deterministically in tests
/// instead of depending on real wall-clock time.
public protocol EngineClock: Sendable {
    func now() -> Date
}

public struct SystemClock: EngineClock {
    public init() {}
    public func now() -> Date { Date() }
}
