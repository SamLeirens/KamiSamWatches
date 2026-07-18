import Foundation

/// Versioned on-disk backup format. These DTOs mirror the SwiftData models
/// (`TrackedShow`, `WatchEvent`), which cannot conform to `Codable` themselves.
struct BackupFile: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var shows: [BackupShow]
    var events: [BackupWatchEvent]
}

struct BackupShow: Codable {
    var tmdbId: Int
    var showName: String
    var addedAt: Date
    var hiddenFromWatchNext: Bool
}

struct BackupWatchEvent: Codable {
    var tmdbShowId: Int
    var season: Int
    var episodeNumber: Int
    var durationMinutes: Int
    var watchedAt: Date
}
