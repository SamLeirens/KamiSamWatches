import Foundation
import SwiftUI

enum ReleaseKind: Sendable {
    case episode(season: Int, episodeNumber: Int)
    case seasonPremiere(season: Int)

    var label: String {
        switch self {
        case .episode(let s, let e): return "S\(s) E\(e)"
        case .seasonPremiere(let s): return "Season \(s) Premiere"
        }
    }

    var badgeLabel: String {
        switch self {
        case .seasonPremiere: return "Premiere"
        case .episode: return "New"
        }
    }

    var badgeColor: Color {
        switch self {
        case .seasonPremiere: return .orange
        case .episode: return .accentColor
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
    let posterURL: URL?

    var id: String {
        switch kind {
        case .episode(let s, let e): return "\(tmdbShowId)-S\(s)E\(e)"
        case .seasonPremiere(let s): return "\(tmdbShowId)-S\(s)E1"
        }
    }

    func googleCalendarURL() -> URL? {
        let style = Date.VerbatimFormatStyle(
            format: "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)",
            timeZone: .gmt,
            calendar: Calendar(identifier: .gregorian)
        )
        let startStr = releaseDate.formatted(style)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: releaseDate) ?? releaseDate
        let endStr = endDate.formatted(style)

        let title = "\(showName) – \(self.title)"
        let details = kind.label + (overview.isEmpty ? "" : "\n\n\(overview)")

        guard var components = URLComponents(string: "https://calendar.google.com/calendar/render") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: title),
            URLQueryItem(name: "dates", value: "\(startStr)/\(endStr)"),
            URLQueryItem(name: "details", value: details),
        ]
        return components.url
    }

    var season: Int {
        switch kind {
        case .episode(let s, _): return s
        case .seasonPremiere(let s): return s
        }
    }

    var episodeNumber: Int {
        switch kind {
        case .episode(_, let e): return e
        case .seasonPremiere: return 1
        }
    }

    var asEpisode: Episode {
        Episode(
            tmdbShowId: tmdbShowId,
            showName: showName,
            title: title,
            season: season,
            episodeNumber: episodeNumber,
            durationMinutes: 0,
            seasonEpisodeCount: 0,
            thumbnailURL: nil,
            airDate: releaseDate,
            badge: nil,
            isWatched: false
        )
    }

    var releaseDayNumber: String {
        releaseDate.formatted(.dateTime.day())
    }

    var releaseMonthAbbrev: String {
        releaseDate.formatted(.dateTime.month(.abbreviated))
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
