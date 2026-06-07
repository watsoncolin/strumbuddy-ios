import SwiftUI

/// Browsable beginner tips, grouped by category.
struct TipsView: View {
    var body: some View {
        List {
            ForEach(Tip.Category.allCases, id: \.rawValue) { category in
                Section(category.rawValue) {
                    ForEach(Tip.library.filter { $0.category == category }) { tip in
                        TipRow(tip: tip)
                    }
                }
            }
        }
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A single tip, reused by the list and the Today card.
struct TipRow: View {
    let tip: Tip

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: tip.icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(tip.title).font(.headline)
                Text(tip.body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
