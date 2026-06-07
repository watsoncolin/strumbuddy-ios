import Foundation

/// Fingering data for a chord diagram (the standard grid showing which fret/finger
/// goes on which string). Strings are ordered low E (6th, index 0) → high E (1st,
/// index 5), matching how a right-handed player reads a diagram.
struct ChordShape {
    /// Fret per string: 0 = open, -1 = muted/not played, >0 = fretted.
    let frets: [Int]
    /// Finger per string (1 = index … 4 = pinky), nil where none.
    let fingers: [Int?]
    /// Optional barre (one finger flattened across several strings at one fret).
    let barre: Barre?

    struct Barre {
        let fret: Int
        let fromString: Int
        let toString: Int
        let finger: Int
    }

    static let library: [Chord: ChordShape] = [
        .e:  ChordShape(frets: [0, 2, 2, 1, 0, 0], fingers: [nil, 2, 3, 1, nil, nil], barre: nil),
        .em: ChordShape(frets: [0, 2, 2, 0, 0, 0], fingers: [nil, 2, 3, nil, nil, nil], barre: nil),
        .a:  ChordShape(frets: [-1, 0, 2, 2, 2, 0], fingers: [nil, nil, 1, 2, 3, nil], barre: nil),
        .am: ChordShape(frets: [-1, 0, 2, 2, 1, 0], fingers: [nil, nil, 2, 3, 1, nil], barre: nil),
        .d:  ChordShape(frets: [-1, -1, 0, 2, 3, 2], fingers: [nil, nil, nil, 1, 3, 2], barre: nil),
        .g:  ChordShape(frets: [3, 2, 0, 0, 0, 3], fingers: [2, 1, nil, nil, nil, 3], barre: nil),
        .c:  ChordShape(frets: [-1, 3, 2, 0, 1, 0], fingers: [nil, 3, 2, nil, 1, nil], barre: nil),
        .f:  ChordShape(frets: [1, 3, 3, 2, 1, 1], fingers: [1, 3, 4, 2, 1, 1],
                        barre: Barre(fret: 1, fromString: 0, toString: 5, finger: 1)),
    ]

    static let unknown = ChordShape(frets: [-1, -1, -1, -1, -1, -1],
                                    fingers: [nil, nil, nil, nil, nil, nil], barre: nil)

    /// Open-string pitch classes in standard tuning, low E (index 0) → high E (5).
    static let openStringPitchClasses = [4, 9, 2, 7, 11, 4]   // E A D G B E
    /// Display names for the open strings, same order.
    static let stringNames = ["E", "A", "D", "G", "B", "e"]

    /// The pitch class a given string sounds with its current fret, or nil if muted.
    func soundingPitchClass(forString i: Int) -> Int? {
        let fret = frets[i]
        guard fret >= 0 else { return nil }
        return (ChordShape.openStringPitchClasses[i] + fret) % 12
    }
}
