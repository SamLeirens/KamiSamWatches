import Foundation
import SwiftData

@Model
final class TrackedShow {
    // All properties have defaults so the schema stays CloudKit-compatible.
    var tmdbId: Int = 0
    var showName: String = ""
    var addedAt: Date = Date.now
    var hiddenFromWatchNext: Bool = false

    init(tmdbId: Int, showName: String, addedAt: Date = .now, hiddenFromWatchNext: Bool = false) {
        self.tmdbId = tmdbId
        self.showName = showName
        self.addedAt = addedAt
        self.hiddenFromWatchNext = hiddenFromWatchNext
    }
}
