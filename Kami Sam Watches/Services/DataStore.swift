import Foundation
import SwiftData
import Observation

@Observable
final class DataStore {
    private(set) var trackedShows: [TrackedShow] = []
    private(set) var watchEvents: [WatchEvent] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        seedDefaultShowsIfNeeded()
        refresh()
    }

    // MARK: - Queries

    func progress(for tmdbShowId: Int) -> (season: Int, episode: Int)? {
        watchEvents
            .filter { $0.tmdbShowId == tmdbShowId }
            .sorted { $0.watchedAt > $1.watchedAt }
            .first
            .map { ($0.season, $0.episodeNumber) }
    }

    var progressLookup: [Int: (season: Int, episode: Int)] {
        Dictionary(uniqueKeysWithValues: trackedShows.compactMap { show in
            progress(for: show.tmdbId).map { (show.tmdbId, $0) }
        })
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

    func isWatched(showId: Int, season: Int, episode: Int) -> Bool {
        watchEvents.contains { $0.tmdbShowId == showId && $0.season == season && $0.episodeNumber == episode }
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

    // MARK: - Stats

    var totalEpisodesWatched: Int { watchEvents.count }

    var totalSeasonsWatched: Int {
        Set(watchEvents.map { "\($0.tmdbShowId)-\($0.season)" }).count
    }

    var totalShowsWatched: Int {
        Set(watchEvents.map { $0.tmdbShowId }).count
    }

    var totalWatchMinutes: Int {
        watchEvents.reduce(0) { $0 + $1.durationMinutes }
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
