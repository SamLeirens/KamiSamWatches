import Foundation
import SwiftData

@Model
final class WatchEvent {
    // All properties have defaults so the schema stays CloudKit-compatible.
    var tmdbShowId: Int = 0
    var season: Int = 0
    var episodeNumber: Int = 0
    var durationMinutes: Int = 0
    var watchedAt: Date = Date.now

    init(tmdbShowId: Int, season: Int, episodeNumber: Int, durationMinutes: Int, watchedAt: Date = .now) {
        self.tmdbShowId = tmdbShowId
        self.season = season
        self.episodeNumber = episodeNumber
        self.durationMinutes = durationMinutes
        self.watchedAt = watchedAt
    }
}
