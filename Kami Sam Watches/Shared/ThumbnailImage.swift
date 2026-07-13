import SwiftUI

enum ThumbnailSize {
    case still          // 16:9, 112×63
    case stillLarge     // 16:9, full width × 200
    case poster         // 2:3, 60×90
    case posterLarge    // 2:3, 100×150

    var fixedWidth: CGFloat? {
        switch self {
        case .still: 112
        case .stillLarge: nil
        case .poster: 60
        case .posterLarge: 100
        }
    }

    var height: CGFloat {
        switch self {
        case .still: 63
        case .stillLarge: 200
        case .poster: 90
        case .posterLarge: 150
        }
    }

    var expandsHorizontally: Bool {
        self == .stillLarge
    }
}

struct ThumbnailImage: View {
    let url: URL?
    let fallbackIcon: String
    var size: ThumbnailSize = .still

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: fallbackIcon)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.fixedWidth, height: size.height)
        .frame(maxWidth: size.expandsHorizontally ? .infinity : nil)
        .background(Theme.imagePlaceholder)
        .clipShape(.rect(cornerRadius: Theme.thumbCornerRadius))
    }
}
