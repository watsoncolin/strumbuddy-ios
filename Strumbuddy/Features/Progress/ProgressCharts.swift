import SwiftUI
import Charts

/// Single-series charts for the progress screen. One hue (the accent), thin marks,
/// recessive axes, no legend (the title names the series), and touch-to-inspect:
/// drag across a chart to read any point's exact value.

/// One-minute changes over time for one chord pair: a 2pt line with point markers
/// and the personal best labeled directly.
struct OneMinuteChart: View {
    let history: [OneMinuteResult]
    @State private var selected: OneMinuteResult?

    private var best: OneMinuteResult? { history.max { $0.changes < $1.changes } }

    var body: some View {
        Chart {
            ForEach(history) { r in
                LineMark(x: .value("Date", r.date), y: .value("Changes", r.changes))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", r.date), y: .value("Changes", r.changes))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(r.id == best?.id || r.id == selected?.id ? 90 : 50)
                    .annotation(position: .top, spacing: 4) {
                        if r.id == best?.id, selected == nil {
                            Text("Best \(r.changes)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
            }
            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, spacing: 0) {
                        ChartTooltip(title: selected.date.formatted(.dateTime.month(.abbreviated).day()),
                                     value: "\(selected.changes) changes")
                    }
            }
        }
        .chartYScale(domain: 0...max(10, (best?.changes ?? 0) + 4))
        .chartYAxis { recessiveYAxis }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
        .chartOverlay { proxy in
            selectionOverlay(proxy: proxy) { (date: Date) in
                selected = history.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
            } clear: { selected = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("One-minute changes history")
        .accessibilityValue(history.map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.changes)" }
                                .joined(separator: ", "))
    }
}

/// Graded attempts per day: thin bars with rounded tops, zero days left visible as
/// gaps so streak breaks read honestly.
struct ActivityChart: View {
    let days: [ProgressStats.Day]
    @State private var selected: ProgressStats.Day?

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Attempts", day.attempts),
                        width: .ratio(0.55))
                    .foregroundStyle(Theme.accent.opacity(selected == nil || selected == day ? 1 : 0.35))
                    .cornerRadius(4)
            }
            if let selected {
                RuleMark(x: .value("Day", selected.date, unit: .day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 0) {
                        ChartTooltip(title: selected.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                                     value: "\(selected.attempts) attempts")
                    }
            }
        }
        .chartYAxis { recessiveYAxis }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartOverlay { proxy in
            selectionOverlay(proxy: proxy) { (date: Date) in
                let cal = Calendar.current
                selected = days.first { cal.isDate($0.date, inSameDayAs: date) }
            } clear: { selected = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Practice attempts per day, last \(days.count) days")
        .accessibilityValue("\(days.filter { $0.attempts > 0 }.count) days practiced, \(days.map(\.attempts).reduce(0, +)) attempts")
    }
}

/// Value readout shown while touching a chart. Text in ink colors, never the series color.
private struct ChartTooltip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption).bold().foregroundStyle(.primary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Light gridlines and muted labels — the data carries the ink, not the frame.
private var recessiveYAxis: some AxisContent {
    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.25))
        AxisValueLabel().foregroundStyle(Color.secondary)
    }
}

/// A full-size hit target over the plot: touch or drag selects the nearest date,
/// lifting the finger clears it.
private func selectionOverlay(proxy: ChartProxy, select: @escaping (Date) -> Void,
                              clear: @escaping () -> Void) -> some View {
    GeometryReader { geo in
        Rectangle().fill(.clear).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let origin = geo[proxy.plotAreaFrame].origin
                    if let date: Date = proxy.value(atX: value.location.x - origin.x) { select(date) }
                }
                .onEnded { _ in clear() })
    }
}
