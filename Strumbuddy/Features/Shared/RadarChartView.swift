import SwiftUI

/// A radar (spider) chart for a skill's profile across N axes (3+). Shows the shape
/// of competence at a glance — a balanced polygon when strong, a dent on weak axes.
/// Values are 0…1. Drawn with Canvas so it scales crisply.
struct RadarChartView: View {
    struct Axis: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    let axes: [Axis]

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .accessibilityLabel("Skill profile radar chart")
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let n = axes.count
        guard n >= 3 else { return }

        let labelInset: CGFloat = 30
        let radius = (min(size.width, size.height) - labelInset * 2) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        func point(_ i: Int, _ r: CGFloat) -> CGPoint {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(n)
            return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        }

        let grid = Color.secondary.opacity(0.25)

        // Concentric grid rings.
        for ring in [0.25, 0.5, 0.75, 1.0] {
            var path = Path()
            for i in 0..<n {
                let pt = point(i, radius * ring)
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
            ctx.stroke(path, with: .color(grid), lineWidth: ring == 1.0 ? 1.5 : 0.75)
        }

        // Spokes + axis labels with their value.
        for i in 0..<n {
            var spoke = Path()
            spoke.move(to: center)
            spoke.addLine(to: point(i, radius))
            ctx.stroke(spoke, with: .color(grid), lineWidth: 0.75)

            let labelPoint = point(i, radius + labelInset * 0.7)
            let text = Text("\(axes[i].label)\n\(Int(axes[i].value * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
            ctx.draw(text, at: labelPoint, anchor: .center)
        }

        // The data polygon.
        var data = Path()
        for i in 0..<n {
            let v = min(max(axes[i].value, 0), 1)
            let pt = point(i, radius * CGFloat(v))
            i == 0 ? data.move(to: pt) : data.addLine(to: pt)
        }
        data.closeSubpath()
        ctx.fill(data, with: .color(Theme.accent.opacity(0.25)))
        ctx.stroke(data, with: .color(Theme.accent), lineWidth: 2)

        // Vertex dots.
        for i in 0..<n {
            let v = min(max(axes[i].value, 0), 1)
            let pt = point(i, radius * CGFloat(v))
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3.5, y: pt.y - 3.5, width: 7, height: 7)),
                     with: .color(Theme.accent))
        }
    }
}

#Preview {
    RadarChartView(axes: [
        .init(label: "Accuracy", value: 0.9),
        .init(label: "Clean", value: 0.6),
        .init(label: "Timing", value: 0.7),
        .init(label: "Consistency", value: 0.4),
    ])
    .frame(width: 260, height: 260)
}
