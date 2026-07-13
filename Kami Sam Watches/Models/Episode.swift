import Foundation

enum EpisodeBadge: String, Sendable {
    case new = "New"
    case latest = "Latest"
    case premiere = "Premiere"
}

struct Episode: Identifiable, Sendable {
    var id: String { "\(tmdbShowId)-S\(season)E\(episodeNumber)" }
    let tmdbShowId: Int
    let showName: String
    let title: String
    let season: Int
    let episodeNumber: Int
    let durationMinutes: Int
    let seasonEpisodeCount: Int
    let thumbnailURL: URL?
    let airDate: Date?
    let badge: EpisodeBadge?
    var isWatched: Bool

    var label: String { "S\(season) E\(episodeNumber)" }

    var seasonProgress: Double? {
        guard seasonEpisodeCount > 0 else { return nil }
        return Double(episodeNumber - 1) / Double(seasonEpisodeCount)
    }
}
