import SwiftUI

/// Single source of truth for formatting elapsed time and applying the
/// gentle passive color shift once past target — used identically by the
/// menu bar label and the main window so they stay in lockstep.
struct TimeDisplayText: View {
    let elapsedSeconds: Double
    let isOverTarget: Bool
    var font: Font = .body

    var body: some View {
        Text(Self.formatted(elapsedSeconds))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(Self.color(isOverTarget: isOverTarget))
            .animation(.easeInOut(duration: 0.6), value: isOverTarget)
    }

    static func color(isOverTarget: Bool) -> Color {
        isOverTarget ? .orange : .primary
    }

    static func formatted(_ elapsedSeconds: Double) -> String {
        let total = max(0, Int(elapsedSeconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
