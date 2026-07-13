import SwiftUI

struct BadgeChip: View {
    let label: String
    var color: Color = .accentColor

    init(_ badge: EpisodeBadge) {
        self.label = badge.rawValue
        self.color = badge == .premiere ? .orange : .accentColor
    }

    init(label: String, color: Color = .accentColor) {
        self.label = label
        self.color = color
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
