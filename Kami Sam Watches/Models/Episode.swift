import Foundation

enum EpisodeBadge: String, Sendable {
    case new = "New"
    case latest = "Latest"
    case premiere = "Premiere"
}

struct Episode: Identifiable, Sendable {
    let id: UUID
    let tmdbShowId: Int
    let showName: String
    let title: String
    let season: Int
    let episodeNumber: Int
    let durationMinutes: Int
    let seasonEpisodeCount: Int
    let thumbnailURL: URL?
    let badge: EpisodeBadge?
    var isWatched: Bool

    var label: String { "S\(season) E\(episodeNumber)" }
}
