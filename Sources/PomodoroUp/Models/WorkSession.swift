import Foundation
import SwiftData

@Model
final class WorkSession {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var baseTargetMinutes: Double
    var actualWorkSeconds: Double
    var overrunSeconds: Double
    var baseBreakMinutes: Double
    var adjustedBreakMinutes: Double
    var nextTargetMinutes: Double

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        baseTargetMinutes: Double,
        actualWorkSeconds: Double,
        overrunSeconds: Double,
        baseBreakMinutes: Double,
        adjustedBreakMinutes: Double,
        nextTargetMinutes: Double
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.baseTargetMinutes = baseTargetMinutes
        self.actualWorkSeconds = actualWorkSeconds
        self.overrunSeconds = overrunSeconds
        self.baseBreakMinutes = baseBreakMinutes
        self.adjustedBreakMinutes = adjustedBreakMinutes
        self.nextTargetMinutes = nextTargetMinutes
    }

    convenience init(record: WorkSessionRecord) {
        self.init(
            startDate: record.startDate,
            endDate: record.endDate,
            baseTargetMinutes: record.baseTargetMinutes,
            actualWorkSeconds: record.actualWorkSeconds,
            overrunSeconds: record.overrunSeconds,
            baseBreakMinutes: record.baseBreakMinutes,
            adjustedBreakMinutes: record.adjustedBreakMinutes,
            nextTargetMinutes: record.nextTargetMinutes
        )
    }
}
