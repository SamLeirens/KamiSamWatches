import SwiftUI

struct CardRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cardCornerRadius))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

extension View {
    func cardRow() -> some View {
        modifier(CardRowStyle())
    }
}
