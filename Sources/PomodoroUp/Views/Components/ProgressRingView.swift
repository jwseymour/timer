import SwiftUI

/// A small ring showing progress toward 0...1. When `outerProgress` is
/// non-nil, a second thinner ring is drawn around the first to represent a
/// bounded secondary quantity (e.g. overrun, capped at "full" = 100% over).
/// Dumb/pure — callers own what the progress values mean.
struct ProgressRingView: View {
    var innerProgress: Double
    var outerProgress: Double? = nil
    var innerColor: Color = .accentColor
    var outerColor: Color = .orange
    var diameter: CGFloat = 15

    var body: some View {
        ZStack {
            ring(progress: innerProgress, color: innerColor, lineWidth: 2)
                .frame(width: diameter, height: diameter)

            if let outerProgress {
                ring(progress: outerProgress, color: outerColor, lineWidth: 1.5)
                    .frame(width: diameter + 5, height: diameter + 5)
            }
        }
        .frame(
            width: (outerProgress != nil ? diameter + 5 : diameter),
            height: (outerProgress != nil ? diameter + 5 : diameter)
        )
    }

    private func ring(progress: Double, color: Color, lineWidth: CGFloat) -> some View {
        let clamped = min(max(progress, 0), 1)
        return ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.4), value: clamped)
    }
}
