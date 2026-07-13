import Foundation

enum WatchNextFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case new = "New"
    case premieres = "Premieres"

    var id: String { rawValue }

    func matches(_ episode: Episode) -> Bool {
        switch self {
        case .all:
            return true
        case .new:
            return episode.badge == .new || episode.badge == .latest
        case .premieres:
            return episode.badge == .premiere
        }
    }
}
