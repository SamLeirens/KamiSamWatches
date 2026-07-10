import Foundation
import SwiftData

@Model
final class WatchEvent {
    var tmdbShowId: Int
    var season: Int
    var episodeNumber: Int
    var durationMinutes: Int
    var watchedAt: Date

    init(tmdbShowId: Int, season: Int, episodeNumber: Int, durationMinutes: Int, watchedAt: Date = .now) {
        self.tmdbShowId = tmdbShowId
        self.season = season
        self.episodeNumber = episodeNumber
        self.durationMinutes = durationMinutes
        self.watchedAt = watchedAt
    }
}
