import Foundation
import SwiftData

@Model
final class TrackedShow {
    var tmdbId: Int
    var showName: String
    var addedAt: Date
    var hiddenFromWatchNext: Bool = false

    init(tmdbId: Int, showName: String) {
        self.tmdbId = tmdbId
        self.showName = showName
        self.addedAt = .now
    }
}
