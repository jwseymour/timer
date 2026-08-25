import SwiftUI
import SwiftData

/// Session history — deliberately its own window, never embedded in the
/// main timer view.
struct HistoryView: View {
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "clock",
                    description: Text("Completed work sessions will show up here.")
                )
            } else {
                Table(sessions) {
                    TableColumn("Date") { session in
                        Text(Self.dateFormatter.string(from: session.startDate))
                    }
                    TableColumn("Target") { session in
                        Text("\(Int(session.baseTargetMinutes.rounded())) min")
                    }
                    TableColumn("Worked") { session in
                        Text(TimeDisplayText.formatted(session.actualWorkSeconds))
                    }
                    TableColumn("Overrun") { session in
                        Text(session.overrunSeconds > 0 ? TimeDisplayText.formatted(session.overrunSeconds) : "—")
                    }
                    TableColumn("Break Given") { session in
                        Text("\(Int(session.adjustedBreakMinutes.rounded())) min")
                    }
                    TableColumn("Next Target") { session in
                        Text("\(Int(session.nextTargetMinutes.rounded())) min")
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 340)
    }
}
