import SwiftUI

/// The coach's diagnosis, shown as a short note — the "show its reasoning" half of
/// the coach (design-doc §5.4). Used by the drill, song, and daily-session summaries.
struct CoachNoteView: View {
    let title: String
    let message: String
    var icon = "person.wave.2"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(Theme.accent)
            Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// One dot per graded rep, tinted by score, with the chord under it and a late/early
/// mark — so you can see *where* in the run it went wrong.
struct RepStripView: View {
    let results: [RepResult]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(results) { rep in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(color(rep.axes.overall))
                            .frame(width: 18, height: 18)
                        Text(rep.chord.displayName).font(.caption2).bold()
                        Text(timingMark(rep)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rep \(rep.id + 1), \(rep.chord.displayName), \(Int(rep.axes.overall * 100)) percent \(timingMark(rep))")
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
        }
    }

    private func timingMark(_ rep: RepResult) -> String {
        guard let offset = rep.timingOffset else { return " " }
        if offset > DrillDiagnosis.offBeat { return "late" }
        if offset < -DrillDiagnosis.offBeat { return "early" }
        return " "
    }

    private func color(_ v: Double) -> Color {
        v >= SongReport.cleanThreshold ? Theme.clean : (v >= 0.5 ? Theme.shaky : Theme.missed)
    }
}
