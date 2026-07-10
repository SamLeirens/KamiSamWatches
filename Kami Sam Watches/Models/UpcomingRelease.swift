import Foundation

enum ReleaseKind: Sendable {
    case episode(season: Int, episodeNumber: Int)
    case seasonPremiere(season: Int)

    var label: String {
        switch self {
        case .episode(let s, let e): return "S\(s) E\(e)"
        case .seasonPremiere(let s): return "Season \(s) Premiere"
        }
    }
}

struct UpcomingRelease: Identifiable, Sendable {
    let tmdbShowId: Int
    let showName: String
    let title: String
    let kind: ReleaseKind
    let overview: String
    let releaseDate: Date
    let thumbnailURL: URL?

    var id: String {
        switch kind {
        case .episode(let s, let e): return "\(tmdbShowId)-S\(s)E\(e)"
        case .seasonPremiere(let s): return "\(tmdbShowId)-S\(s)E1"
        }
    }

    var releaseDateFormatted: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: releaseDate)).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days < 8 { return "in \(days) days" }
        return releaseDate.formatted(date: .abbreviated, time: .omitted)
    }
}
