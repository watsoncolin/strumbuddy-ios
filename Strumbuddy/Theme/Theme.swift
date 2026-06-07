import SwiftUI

/// Central style tokens. Warm, encouraging, beginner-safe — the brand the name
/// promises. Keep visual constants here so screens stay consistent.
enum Theme {
    static let accent = Color("AccentColor")

    // Scoring colors — used to surface the four-axis grade (design-doc §4).
    static let clean = Color.green
    static let shaky = Color.orange
    static let missed = Color.red

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
    }

    enum Radius {
        static let card: CGFloat = 16
        static let pill: CGFloat = 999
    }
}
