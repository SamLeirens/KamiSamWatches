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

extension Episode {
    /// Builds a display episode from a TMDB season-detail episode.
    init(tmdb: TMDBEpisode, showId: Int, showName: String, seasonEpisodeCount: Int, isWatched: Bool) {
        self.init(
            tmdbShowId: showId,
            showName: showName,
            title: tmdb.name,
            season: tmdb.season_number,
            episodeNumber: tmdb.episode_number,
            durationMinutes: tmdb.runtime ?? 0,
            seasonEpisodeCount: seasonEpisodeCount,
            thumbnailURL: TMDBFormat.imageURL(path: tmdb.still_path),
            airDate: TMDBFormat.parseDate(tmdb.air_date),
            badge: nil,
            isWatched: isWatched
        )
    }
}
