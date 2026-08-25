import Foundation
@testable import PomodoroUp

final class FakeClock: EngineClock, @unchecked Sendable {
    private var current: Date

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.current = start
    }

    func now() -> Date { current }

    func advance(seconds: Double) {
        current = current.addingTimeInterval(seconds)
    }

    func advance(minutes: Double) {
        advance(seconds: minutes * 60)
    }
}
