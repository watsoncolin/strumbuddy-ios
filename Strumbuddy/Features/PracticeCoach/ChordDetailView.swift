import SwiftUI

/// Per-chord detail: the four scoring dimensions plus mastery context, from the
/// coach's aggregated observations. Reached by tapping a chord in "Your chords".
struct ChordDetailView: View {
    let chord: Chord
    @ObservedObject var coach: Coach

    var body: some View {
        let detail = coach.detail(for: .chord(chord))
        List {
            Section {
                HStack {
                    Spacer()
                    ChordDiagramView(chord: chord).frame(width: 120, height: 156)
                    Spacer()
                }
            }

            Section("Mastery") {
                LabeledContent("Status") {
                    if detail.mastered {
                        Label("Mastered", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.clean)
                    } else {
                        Text("Learning").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Proficiency", value: "\(Int(detail.proficiency * 100))%")
                LabeledContent("Attempts", value: "\(detail.attempts)")
                if let last = detail.lastPracticed, detail.attempts > 0 {
                    LabeledContent("Last played") { Text(last, style: .relative) + Text(" ago") }
                }
            }

            Section("The four dimensions") {
                axisRow("Accuracy", detail.accuracy, "Right notes")
                axisRow("Cleanliness", detail.cleanliness, "Every string ringing")
                if detail.hasTiming {
                    axisRow("Timing", detail.timing, "On the beat")
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Timing").font(.subheadline)
                        Text("Play the transition drill to grade this.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                axisRow("Consistency", detail.consistency, "How reliably you nail it")
            }
        }
        .navigationTitle("\(chord.displayName) chord")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func axisRow(_ label: String, _ value: Double, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1)).tint(color(value))
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func color(_ v: Double) -> Color {
        v >= 0.8 ? Theme.clean : (v >= 0.5 ? Theme.shaky : Theme.missed)
    }
}
