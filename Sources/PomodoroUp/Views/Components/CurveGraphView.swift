import SwiftUI

/// A small line graph with draggable control points — the v2 curve editor
/// promised in place of raw numeric constant fields. Dumb/generic: callers
/// own what the curve and points mean, this just draws it and reports drag
/// results back in data space via each point's `onChange`.
struct CurveGraphView: View {
    struct ControlPoint: Identifiable {
        enum DragAxis { case free, horizontal, vertical }

        let id: String
        var position: CGPoint
        var dragAxis: DragAxis = .free
        var color: Color = .accentColor
        var onChange: (CGPoint) -> Void
    }

    let title: String
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    let curve: (Double) -> Double
    var controlPoints: [ControlPoint] = []
    var height: CGFloat = 140

    private let sampleCount = 60
    private let coordinateSpaceName = "curveGraph"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    axes(size: geo.size)
                    curvePath(size: geo.size)
                        .stroke(Color.accentColor, lineWidth: 2)
                    ForEach(controlPoints) { point in
                        handle(for: point, size: geo.size)
                    }
                }
                .coordinateSpace(name: coordinateSpaceName)
            }
            .frame(height: height)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Data <-> view space

    private func viewX(_ dataX: Double, width: CGFloat) -> CGFloat {
        let span = max(xRange.upperBound - xRange.lowerBound, 0.0001)
        return CGFloat((dataX - xRange.lowerBound) / span) * width
    }

    private func viewY(_ dataY: Double, height: CGFloat) -> CGFloat {
        let span = max(yRange.upperBound - yRange.lowerBound, 0.0001)
        return height - CGFloat((dataY - yRange.lowerBound) / span) * height
    }

    private func dataX(_ viewX: CGFloat, width: CGFloat) -> Double {
        let t = Double(viewX / max(width, 0.0001))
        return xRange.lowerBound + t * (xRange.upperBound - xRange.lowerBound)
    }

    private func dataY(_ viewY: CGFloat, height: CGFloat) -> Double {
        let t = Double((height - viewY) / max(height, 0.0001))
        return yRange.lowerBound + t * (yRange.upperBound - yRange.lowerBound)
    }

    // MARK: - Drawing

    private func curvePath(size: CGSize) -> Path {
        Path { path in
            for i in 0...sampleCount {
                let x = xRange.lowerBound + (xRange.upperBound - xRange.lowerBound) * Double(i) / Double(sampleCount)
                let y = curve(x)
                let point = CGPoint(x: viewX(x, width: size.width), y: viewY(y, height: size.height))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func axes(size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: size.height))
        }
        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
    }

    private func handle(for point: ControlPoint, size: CGSize) -> some View {
        let viewPoint = CGPoint(x: viewX(point.position.x, width: size.width), y: viewY(point.position.y, height: size.height))
        return Circle()
            .fill(point.color)
            .frame(width: 12, height: 12)
            .shadow(radius: 1)
            .position(viewPoint)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                    .onChanged { value in
                        var newX = point.position.x
                        var newY = point.position.y
                        if point.dragAxis != .vertical {
                            newX = min(max(dataX(value.location.x, width: size.width), xRange.lowerBound), xRange.upperBound)
                        }
                        if point.dragAxis != .horizontal {
                            newY = min(max(dataY(value.location.y, height: size.height), yRange.lowerBound), yRange.upperBound)
                        }
                        point.onChange(CGPoint(x: newX, y: newY))
                    }
            )
    }
}
