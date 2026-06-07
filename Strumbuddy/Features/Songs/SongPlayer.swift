import Foundation
import Combine

/// Drives a guided song play-along: the metronome keeps time and the current chord
/// advances one per bar, looping. No grading — this is the motivation payoff
/// (play a real song), so it just guides; the mic isn't needed.
@MainActor
final class SongPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var index = 0
    @Published private(set) var beatInBar = 0

    let song: Song
    private let metronome: Metronome
    private let sequence: [Chord]
    private var firstDownbeat = true
    private var cancellable: AnyCancellable?

    init(song: Song, metronome: Metronome) {
        self.song = song
        self.metronome = metronome
        self.sequence = song.flatChords
    }

    var current: Chord? { sequence.indices.contains(index) ? sequence[index] : nil }
    var next: Chord? { sequence.isEmpty ? nil : sequence[(index + 1) % sequence.count] }

    func start() {
        index = 0
        firstDownbeat = true
        metronome.bpm = song.bpm
        cancellable = metronome.$beatInBar.sink { [weak self] beat in
            guard let self else { return }
            self.beatInBar = beat
            if beat == 1 { self.onDownbeat() }
        }
        metronome.start()
        isPlaying = true
    }

    func stop() {
        cancellable = nil
        metronome.stop()
        isPlaying = false
    }

    private func onDownbeat() {
        // The first downbeat starts chord 0; each later one advances (and loops).
        if firstDownbeat {
            firstDownbeat = false
        } else if !sequence.isEmpty {
            index = (index + 1) % sequence.count
        }
    }
}
