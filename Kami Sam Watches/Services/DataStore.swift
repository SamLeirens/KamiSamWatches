import Foundation
import SwiftData
import Observation

// MARK: - Key types for O(1) watched lookups

struct EpisodeKey: Hashable, Sendable {
    let showId: Int
    let season: Int
    let episode: Int
}

struct SeasonKey: Hashable, Sendable {
    let showId: Int
    let season: Int
}

// MARK: - DataStore

@Observable
final class DataStore {
    private(set) var trackedShows: [TrackedShow] = []
    private(set) var watchEvents: [WatchEvent] = []

    // Derived state — recomputed once per refresh(), never per-render
    private(set) var progressLookup: [Int: (season: Int, episode: Int)] = [:]
    private(set) var lastWatchedAt: [Int: Date] = [:]
    private(set) var watchedKeys: Set<EpisodeKey> = []
    private(set) var seasonWatchedCounts: [SeasonKey: Int] = [:]
    private(set) var showNameLookup: [Int: String] = [:]
    private(set) var totalEpisodesWatched: Int = 0
    private(set) var totalSeasonsWatched: Int = 0
    private(set) var totalShowsWatched: Int = 0
    private(set) var totalWatchMinutes: Int = 0

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        seedDefaultShowsIfNeeded()
        refresh()
    }

    // MARK: - Queries

    func progress(for tmdbShowId: Int) -> (season: Int, episode: Int)? {
        progressLookup[tmdbShowId]
    }

    func isWatched(showId: Int, season: Int, episode: Int) -> Bool {
        watchedKeys.contains(EpisodeKey(showId: showId, season: season, episode: episode))
    }

    func watchedCount(showId: Int, season: Int) -> Int {
        seasonWatchedCounts[SeasonKey(showId: showId, season: season), default: 0]
    }

    func seasonProgress(showId: Int, season: Int, totalEpisodes: Int?) -> Double? {
        guard let total = totalEpisodes, total > 0 else { return nil }
        let watched = watchedCount(showId: showId, season: season)
        return min(1.0, Double(watched) / Double(total))
    }

    func showName(for tmdbId: Int) -> String {
        showNameLookup[tmdbId] ?? "Unknown Show"
    }

    // MARK: - Mutations

    func markWatched(episode: Episode) {
        let event = WatchEvent(
            tmdbShowId: episode.tmdbShowId,
            season: episode.season,
            episodeNumber: episode.episodeNumber,
            durationMinutes: episode.durationMinutes
        )
        modelContext.insert(event)
        save()
        refresh()
    }

    func toggleWatched(showId: Int, season: Int, episode: Int, durationMinutes: Int) {
        if let existing = watchEvents.first(where: {
            $0.tmdbShowId == showId && $0.season == season && $0.episodeNumber == episode
        }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(WatchEvent(tmdbShowId: showId, season: season, episodeNumber: episode, durationMinutes: durationMinutes))
        }
        save()
        refresh()
    }

    func setWatched(showId: Int, season: Int, episodes: [(number: Int, durationMinutes: Int)], watched: Bool) {
        if watched {
            for ep in episodes where !isWatched(showId: showId, season: season, episode: ep.number) {
                modelContext.insert(WatchEvent(tmdbShowId: showId, season: season, episodeNumber: ep.number, durationMinutes: ep.durationMinutes))
            }
        } else {
            let numbers = Set(episodes.map { $0.number })
            watchEvents
                .filter { $0.tmdbShowId == showId && $0.season == season && numbers.contains($0.episodeNumber) }
                .forEach { modelContext.delete($0) }
        }
        save()
        refresh()
    }

    func addShow(tmdbId: Int, showName: String) {
        guard !trackedShows.contains(where: { $0.tmdbId == tmdbId }) else { return }
        modelContext.insert(TrackedShow(tmdbId: tmdbId, showName: showName))
        save()
        refresh()
    }

    // MARK: - Import

    struct ImportResult {
        var showsAdded = 0
        var episodesImported = 0
        var duplicatesSkipped = 0
    }

    func importData(shows: [(tmdbId: Int, name: String)], events: [WatchEvent]) -> ImportResult {
        var result = ImportResult()

        var trackedIds = Set(trackedShows.map(\.tmdbId))
        for show in shows where !trackedIds.contains(show.tmdbId) {
            modelContext.insert(TrackedShow(tmdbId: show.tmdbId, showName: show.name))
            trackedIds.insert(show.tmdbId)
            result.showsAdded += 1
        }

        var existingKeys = Set(watchEvents.map { "\($0.tmdbShowId)-\($0.season)-\($0.episodeNumber)" })
        var batchKeys = Set<String>()
        for event in events {
            let key = "\(event.tmdbShowId)-\(event.season)-\(event.episodeNumber)"
            let batchKey = "\(key)-\(event.watchedAt.timeIntervalSince1970)"
            if existingKeys.contains(key) || batchKeys.contains(batchKey) {
                result.duplicatesSkipped += 1
                continue
            }
            batchKeys.insert(batchKey)
            modelContext.insert(event)
            result.episodesImported += 1
        }

        save()
        refresh()
        return result
    }

    func setHidden(tmdbId: Int, hidden: Bool) {
        guard let show = trackedShows.first(where: { $0.tmdbId == tmdbId }) else { return }
        show.hiddenFromWatchNext = hidden
        save()
        refresh()
    }

    func removeShow(_ show: TrackedShow) {
        modelContext.delete(show)
        save()
        refresh()
    }

    // MARK: - Private

    private func refresh() {
        trackedShows = (try? modelContext.fetch(FetchDescriptor<TrackedShow>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
        watchEvents = (try? modelContext.fetch(FetchDescriptor<WatchEvent>(sortBy: [SortDescriptor(\.watchedAt, order: .reverse)]))) ?? []
        recomputeDerived()
    }

    private func recomputeDerived() {
        showNameLookup = Dictionary(uniqueKeysWithValues: trackedShows.map { ($0.tmdbId, $0.showName) })

        var keys = Set<EpisodeKey>()
        var seasonCounts: [SeasonKey: Int] = [:]
        var uniqueSeasons = Set<SeasonKey>()
        var uniqueShows = Set<Int>()
        var totalMinutes = 0
        var progresses: [Int: (season: Int, episode: Int)] = [:]
        var latestWatched: [Int: Date] = [:]

        // watchEvents is sorted descending by watchedAt — first seen per show is the most recent
        for event in watchEvents {
            let eKey = EpisodeKey(showId: event.tmdbShowId, season: event.season, episode: event.episodeNumber)
            keys.insert(eKey)

            let sKey = SeasonKey(showId: event.tmdbShowId, season: event.season)
            seasonCounts[sKey, default: 0] += 1
            uniqueSeasons.insert(sKey)
            uniqueShows.insert(event.tmdbShowId)
            totalMinutes += event.durationMinutes
            if latestWatched[event.tmdbShowId] == nil { latestWatched[event.tmdbShowId] = event.watchedAt }

            let existing = progresses[event.tmdbShowId]
            if existing == nil
                || event.season > existing!.season
                || (event.season == existing!.season && event.episodeNumber > existing!.episode) {
                progresses[event.tmdbShowId] = (event.season, event.episodeNumber)
            }
        }

        watchedKeys = keys
        seasonWatchedCounts = seasonCounts
        totalEpisodesWatched = watchEvents.count
        totalSeasonsWatched = uniqueSeasons.count
        totalShowsWatched = uniqueShows.count
        totalWatchMinutes = totalMinutes
        progressLookup = progresses
        lastWatchedAt = latestWatched
    }

    private func save() {
        try? modelContext.save()
    }

    private func seedDefaultShowsIfNeeded() {
        let existing = (try? modelContext.fetch(FetchDescriptor<TrackedShow>()))?.count ?? 0
        guard existing == 0 else { return }
        let seeds: [(Int, String)] = [
            (95396,  "Severance"),
            (136315, "The Bear"),
            (97546,  "Slow Horses"),
            (126308, "Shōgun"),
            (110316, "The White Lotus"),
        ]
        for (id, name) in seeds {
            modelContext.insert(TrackedShow(tmdbId: id, showName: name))
        }
        save()
    }
}
