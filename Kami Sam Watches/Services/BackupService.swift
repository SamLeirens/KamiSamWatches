import Foundation

/// Encodes and decodes the JSON backup file used for phone-to-phone migration.
/// Mutation of the store stays in `DataStore.restore`.
struct BackupService {
    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return String(localized: "This backup was made by a newer version of the app (format \(version)). Update the app and try again.")
            case .invalidFormat:
                return String(localized: "This file doesn't look like a Kami Sam Watches backup.")
            }
        }
    }

    func export(shows: [TrackedShow], events: [WatchEvent]) throws -> Data {
        let file = BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: .now,
            shows: shows.map {
                BackupShow(tmdbId: $0.tmdbId, showName: $0.showName, addedAt: $0.addedAt, hiddenFromWatchNext: $0.hiddenFromWatchNext)
            },
            events: events.map {
                BackupWatchEvent(tmdbShowId: $0.tmdbShowId, season: $0.season, episodeNumber: $0.episodeNumber, durationMinutes: $0.durationMinutes, watchedAt: $0.watchedAt)
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(file)
    }

    func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        guard file.version <= BackupFile.currentVersion else {
            throw BackupError.unsupportedVersion(file.version)
        }
        return file
    }

    static func defaultFilename() -> String {
        "KamiSamWatches-Backup-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))"
    }
}
