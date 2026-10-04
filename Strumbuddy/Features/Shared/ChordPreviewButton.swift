import SwiftUI

/// "Hear it" — strums the chord so a beginner knows what clean should sound like
/// before (and while) they try it. Sits under a `ChordDiagramView`.
struct ChordPreviewButton: View {
    let chord: Chord
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        PreviewButtonBody(chord: chord, player: env.chordPreview)
    }
}

/// Split out so the button observes the player's playing state.
private struct PreviewButtonBody: View {
    let chord: Chord
    @ObservedObject var player: ChordPreviewPlayer

    private var isPlaying: Bool { player.playing == chord }

    var body: some View {
        Button { player.play(chord) } label: {
            Label("Hear it", systemImage: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Theme.accent)
        .accessibilityLabel("Play \(chord.displayName) chord")
    }
}
