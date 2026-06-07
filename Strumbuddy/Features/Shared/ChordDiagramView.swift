import SwiftUI

/// A standard chord diagram: nut at top, strings vertical (low E on the left),
/// dots for fretted notes with finger numbers, ○ for open and ✕ for muted strings.
/// Drawn with Canvas so it scales crisply at any size.
struct ChordDiagramView: View {
    let chord: Chord
    /// How many fret rows to show. All beginner open chords fit within 4.
    private let fretCount = 4

    private var shape: ChordShape { ChordShape.library[chord] ?? ChordShape.unknown }

    var body: some View {
        Canvas { context, size in
            draw(&context, size: size)
        }
        .aspectRatio(0.82, contentMode: .fit)
        .accessibilityLabel("\(chord.displayName) chord diagram")
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let strings = 6
        let top = size.height * 0.16          // room for ○ / ✕ markers
        let bottom = size.height * 0.97
        let left = size.width * 0.13
        let right = size.width * 0.87
        let colSpacing = (right - left) / CGFloat(strings - 1)
        let rowSpacing = (bottom - top) / CGFloat(fretCount)

        func x(_ s: Int) -> CGFloat { left + CGFloat(s) * colSpacing }
        func y(_ f: Int) -> CGFloat { top + CGFloat(f) * rowSpacing }

        let line = Color.primary.opacity(0.55)

        // Strings (vertical).
        for s in 0..<strings {
            var p = Path()
            p.move(to: CGPoint(x: x(s), y: top))
            p.addLine(to: CGPoint(x: x(s), y: bottom))
            ctx.stroke(p, with: .color(line), lineWidth: 1)
        }
        // Frets (horizontal); the nut (fret 0) is thick.
        for f in 0...fretCount {
            var p = Path()
            p.move(to: CGPoint(x: left, y: y(f)))
            p.addLine(to: CGPoint(x: right, y: y(f)))
            ctx.stroke(p, with: .color(line), lineWidth: f == 0 ? 4 : 1)
        }

        let dotColor = Color.primary
        let radius = colSpacing * 0.30

        // Barre (drawn behind the finger dots).
        if let barre = shape.barre {
            let cy = (y(barre.fret - 1) + y(barre.fret)) / 2
            let x1 = x(barre.fromString), x2 = x(barre.toString)
            let rect = CGRect(x: min(x1, x2) - radius, y: cy - radius,
                              width: abs(x2 - x1) + 2 * radius, height: 2 * radius)
            ctx.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(dotColor))
        }

        // Markers above the nut + fretted dots.
        for s in 0..<strings {
            let fret = shape.frets[s]
            let sx = x(s)
            if fret == -1 {
                label(&ctx, "✕", at: CGPoint(x: sx, y: top * 0.5), size: top * 0.55, color: .secondary)
            } else if fret == 0 {
                label(&ctx, "○", at: CGPoint(x: sx, y: top * 0.5), size: top * 0.55, color: .secondary)
            } else {
                if let barre = shape.barre, fret == barre.fret { continue }  // covered by barre
                let cy = (y(fret - 1) + y(fret)) / 2
                ctx.fill(Path(ellipseIn: CGRect(x: sx - radius, y: cy - radius,
                                                width: 2 * radius, height: 2 * radius)),
                         with: .color(dotColor))
                if let finger = shape.fingers[s] {
                    label(&ctx, "\(finger)", at: CGPoint(x: sx, y: cy),
                          size: radius * 1.3, color: Color(.systemBackground))
                }
            }
        }
    }

    private func label(_ ctx: inout GraphicsContext, _ s: String, at p: CGPoint,
                       size: CGFloat, color: Color) {
        ctx.draw(Text(s).font(.system(size: size, weight: .semibold)).foregroundColor(color),
                 at: p, anchor: .center)
    }
}

#Preview {
    HStack {
        ChordDiagramView(chord: .em)
        ChordDiagramView(chord: .c)
        ChordDiagramView(chord: .f)
    }
    .frame(height: 160)
    .padding()
}
