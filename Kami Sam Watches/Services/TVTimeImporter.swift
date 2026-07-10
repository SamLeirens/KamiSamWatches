import Foundation
import ZIPFoundation

// MARK: - CSV parsing

enum CSVParser {
    /// RFC 4180 parser — handles quoted fields, escaped quotes, and CRLF line endings.
    nonisolated static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character? = nil

        func endField() {
            row.append(field)
            field = ""
        }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let ch = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if ch == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = next
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",": endField()
                case "\r": break
                case "\n", "\r\n": endRow()
                default: field.append(ch)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    /// Parses CSV text with a header row into dictionaries keyed by column name.
    nonisolated static func parseRecords(_ text: String) -> [[String: String]] {
        let rows = parse(text)
        guard let header = rows.first else { return [] }
        return rows.dropFirst().map { row in
            var record: [String: String] = [:]
            for (index, column) in header.enumerated() where index < row.count {
                record[column] = row[index]
            }
            return record
        }
    }
}

// MARK: - TV Time export models

struct TVTimeEpisodeRecord: Sendable, Equatable {
    let tvdbShowId: Int
    let showName: String
    let season: Int
    let episode: Int
    let runtimeMinutes: Int
    let watchedAt: Date
}

enum TVTimeParser {
    nonisolated static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Extracts watched-episode records from tracking-prod-records-v2.csv content.
    nonisolated static func episodeRecords(fromCSV text: String) -> [TVTimeEpisodeRecord] {
        CSVParser.parseRecords(text).compactMap { record in
            guard let key = record["key"],
                  key.hasPrefix("watch-episode") || key.hasPrefix("rewatch-episode"),
                  let showId = record["s_id"].flatMap(Int.init),
                  let showName = record["series_name"], !showName.isEmpty,
                  let season = record["season_number"].flatMap(Int.init), season >= 0,
                  let episode = record["episode_number"].flatMap(Int.init), episode > 0,
                  let watchedAt = record["created_at"].flatMap(dateFormatter.date(from:))
            else { return nil }
            let runtimeSeconds = record["runtime"].flatMap(Int.init) ?? 0
            return TVTimeEpisodeRecord(
                tvdbShowId: showId,
                showName: showName,
                season: season,
                episode: episode,
                runtimeMinutes: runtimeSeconds / 60,
                watchedAt: watchedAt
            )
        }
    }
}

// MARK: - Importer

struct TVTimeImporter {
    enum Phase: Equatable {
        case readingArchive
        case matchingShows(done: Int, total: Int)
        case saving
    }

    struct Summary {
        var showsAdded: Int
        var episodesImported: Int
        var duplicatesSkipped: Int
        var unresolvedShows: [String]
    }

    enum ImportError: LocalizedError {
        case csvNotFound

        var errorDescription: String? {
            switch self {
            case .csvNotFound:
                return String(localized: "The archive doesn't contain a TV Time watch history (tracking-prod-records-v2.csv).")
            }
        }
    }

    let tmdb: TMDBService

    func run(zipURL: URL, dataStore: DataStore, onPhase: (Phase) -> Void) async throws -> Summary {
        onPhase(.readingArchive)

        let records = try extractRecords(zipURL: zipURL)

        // Resolve each distinct TVDB show id to a TMDB show.
        var showNames: [Int: String] = [:]
        for record in records where showNames[record.tvdbShowId] == nil {
            showNames[record.tvdbShowId] = record.showName
        }

        let total = showNames.count
        var resolved: [Int: (tmdbId: Int, name: String)] = [:]
        var unresolvedShows: [String] = []
        var done = 0
        onPhase(.matchingShows(done: 0, total: total))

        for (tvdbId, name) in showNames.sorted(by: { $0.value < $1.value }) {
            if let match = await resolveShow(tvdbId: tvdbId, name: name) {
                resolved[tvdbId] = match
            } else {
                unresolvedShows.append(name)
            }
            done += 1
            onPhase(.matchingShows(done: done, total: total))
        }

        onPhase(.saving)

        let events = records.compactMap { record -> WatchEvent? in
            guard let show = resolved[record.tvdbShowId] else { return nil }
            return WatchEvent(
                tmdbShowId: show.tmdbId,
                season: record.season,
                episodeNumber: record.episode,
                durationMinutes: record.runtimeMinutes,
                watchedAt: record.watchedAt
            )
        }

        let result = dataStore.importData(shows: Array(resolved.values), events: events)
        return Summary(
            showsAdded: result.showsAdded,
            episodesImported: result.episodesImported,
            duplicatesSkipped: result.duplicatesSkipped,
            unresolvedShows: unresolvedShows
        )
    }

    // MARK: - Private

    private func extractRecords(zipURL: URL) throws -> [TVTimeEpisodeRecord] {
        let fileManager = FileManager.default
        let workDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDir) }

        try fileManager.unzipItem(at: zipURL, to: workDir)

        guard let csvURL = findFile(named: "tracking-prod-records-v2.csv", under: workDir) else {
            throw ImportError.csvNotFound
        }
        let text = try String(contentsOf: csvURL, encoding: .utf8)
        return TVTimeParser.episodeRecords(fromCSV: text)
    }

    private func findFile(named name: String, under directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == name { return url }
        }
        return nil
    }

    private func resolveShow(tvdbId: Int, name: String) async -> (tmdbId: Int, name: String)? {
        if let match = try? await tmdb.findShow(tvdbId: tvdbId) {
            return (match.id, match.name)
        }
        if let match = try? await tmdb.searchShows(query: name).first {
            return (match.id, match.name)
        }
        return nil
    }
}
