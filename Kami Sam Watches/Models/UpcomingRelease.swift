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

    func googleCalendarURL() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let startStr = formatter.string(from: releaseDate)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: releaseDate) ?? releaseDate
        let endStr = formatter.string(from: endDate)

        let title = "\(showName) – \(title)"
        let details = kind.label + (overview.isEmpty ? "" : "\n\n\(overview)")

        var components = URLComponents(string: "https://calendar.google.com/calendar/render")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: title),
            URLQueryItem(name: "dates", value: "\(startStr)/\(endStr)"),
            URLQueryItem(name: "details", value: details),
        ]
        return components.url
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
