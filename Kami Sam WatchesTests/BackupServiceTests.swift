import XCTest
import SwiftData
@testable import Kami_Sam_Watches

@MainActor
final class BackupServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var store: Kami_Sam_Watches.DataStore!
    private let service = BackupService()

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: TrackedShow.self, WatchEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = Kami_Sam_Watches.DataStore(modelContext: container.mainContext)
    }

    override func tearDown() {
        store = nil
        container = nil
    }

    private func makeFreshStore() throws -> (ModelContainer, Kami_Sam_Watches.DataStore) {
        let freshContainer = try ModelContainer(
            for: TrackedShow.self, WatchEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (freshContainer, Kami_Sam_Watches.DataStore(modelContext: freshContainer.mainContext))
    }

    /// A date with deliberate sub-second precision, to exercise ISO8601 truncation.
    private let watchedDate = Date(timeIntervalSince1970: 1_700_000_000.75)
    private let addedDate = Date(timeIntervalSince1970: 1_690_000_000.25)

    private func seedStore() {
        container.mainContext.insert(TrackedShow(tmdbId: 100, showName: "Severance", addedAt: addedDate, hiddenFromWatchNext: true))
        container.mainContext.insert(TrackedShow(tmdbId: 200, showName: "Dark", addedAt: addedDate))
        container.mainContext.insert(WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 1, durationMinutes: 45, watchedAt: watchedDate))
        container.mainContext.insert(WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 2, durationMinutes: 50, watchedAt: watchedDate.addingTimeInterval(3600)))
        try? container.mainContext.save()
        // Rebuild the store so it picks up the seeded rows
        store = Kami_Sam_Watches.DataStore(modelContext: container.mainContext)
    }

    // MARK: - Export / decode

    func testExportDecodeRoundTripPreservesAllFields() throws {
        seedStore()
        let data = try service.export(shows: store.trackedShows, events: store.watchEvents)
        let file = try service.decode(data)

        XCTAssertEqual(file.version, BackupFile.currentVersion)
        XCTAssertEqual(file.shows.count, 2)
        XCTAssertEqual(file.events.count, 2)

        let severance = try XCTUnwrap(file.shows.first { $0.tmdbId == 100 })
        XCTAssertEqual(severance.showName, "Severance")
        XCTAssertTrue(severance.hiddenFromWatchNext)
        XCTAssertEqual(Int(severance.addedAt.timeIntervalSince1970), Int(addedDate.timeIntervalSince1970))

        let episode = try XCTUnwrap(file.events.first { $0.episodeNumber == 1 })
        XCTAssertEqual(episode.tmdbShowId, 100)
        XCTAssertEqual(episode.season, 1)
        XCTAssertEqual(episode.durationMinutes, 45)
        XCTAssertEqual(Int(episode.watchedAt.timeIntervalSince1970), Int(watchedDate.timeIntervalSince1970))
    }

    func testDecodeFixtureString() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-07-18T12:00:00Z",
          "shows": [
            { "tmdbId": 42, "showName": "The Expanse", "addedAt": "2025-01-02T03:04:05Z", "hiddenFromWatchNext": false }
          ],
          "events": [
            { "tmdbShowId": 42, "season": 2, "episodeNumber": 5, "durationMinutes": 44, "watchedAt": "2025-06-07T08:09:10Z" }
          ]
        }
        """
        let file = try service.decode(Data(json.utf8))
        XCTAssertEqual(file.version, 1)
        XCTAssertEqual(file.shows.first?.showName, "The Expanse")
        XCTAssertEqual(file.events.first?.season, 2)
        XCTAssertEqual(file.events.first?.episodeNumber, 5)
    }

    func testDecodeUnsupportedVersionThrows() throws {
        let json = """
        { "version": 999, "exportedAt": "2026-07-18T12:00:00Z", "shows": [], "events": [] }
        """
        XCTAssertThrowsError(try service.decode(Data(json.utf8))) { error in
            guard case BackupService.BackupError.unsupportedVersion(let version) = error else {
                return XCTFail("Expected unsupportedVersion, got \(error)")
            }
            XCTAssertEqual(version, 999)
        }
    }

    func testDecodeGarbageThrowsInvalidFormat() {
        XCTAssertThrowsError(try service.decode(Data("not json at all".utf8))) { error in
            guard case BackupService.BackupError.invalidFormat = error else {
                return XCTFail("Expected invalidFormat, got \(error)")
            }
        }
    }

    // MARK: - Restore

    func testRestoreIntoFreshStoreRecreatesData() throws {
        seedStore()
        let data = try service.export(shows: store.trackedShows, events: store.watchEvents)
        let file = try service.decode(data)

        let (freshContainer, freshStore) = try makeFreshStore()
        _ = freshContainer
        let result = freshStore.restore(shows: file.shows, events: file.events)

        XCTAssertEqual(result.showsAdded, 2)
        XCTAssertEqual(result.episodesImported, 2)
        XCTAssertEqual(result.duplicatesSkipped, 0)

        let severance = try XCTUnwrap(freshStore.trackedShows.first { $0.tmdbId == 100 })
        XCTAssertTrue(severance.hiddenFromWatchNext)
        XCTAssertEqual(Int(severance.addedAt.timeIntervalSince1970), Int(addedDate.timeIntervalSince1970))
        XCTAssertEqual(freshStore.watchEvents.count, 2)
        XCTAssertEqual(freshStore.totalWatchMinutes, 95)
    }

    func testRestoreSameBackupTwiceSkipsAllDuplicates() throws {
        seedStore()
        let data = try service.export(shows: store.trackedShows, events: store.watchEvents)
        let file = try service.decode(data)

        let (freshContainer, freshStore) = try makeFreshStore()
        _ = freshContainer
        _ = freshStore.restore(shows: file.shows, events: file.events)
        let second = freshStore.restore(shows: file.shows, events: file.events)

        XCTAssertEqual(second.showsAdded, 0)
        XCTAssertEqual(second.episodesImported, 0)
        XCTAssertEqual(second.duplicatesSkipped, 2)
        XCTAssertEqual(freshStore.watchEvents.count, 2)
    }

    func testRestoreIntoOriginalStoreIsNoOp() throws {
        // Seeded dates have sub-second precision; ISO8601 export truncates them.
        // Restoring into the same store must still recognize everything as duplicate.
        seedStore()
        let data = try service.export(shows: store.trackedShows, events: store.watchEvents)
        let file = try service.decode(data)

        let result = store.restore(shows: file.shows, events: file.events)

        XCTAssertEqual(result.showsAdded, 0)
        XCTAssertEqual(result.episodesImported, 0)
        XCTAssertEqual(result.duplicatesSkipped, 2)
        XCTAssertEqual(store.watchEvents.count, 2)
        XCTAssertEqual(store.trackedShows.count, 2)
    }

    func testRestorePreservesRewatches() throws {
        let firstWatch = BackupWatchEvent(tmdbShowId: 7, season: 1, episodeNumber: 1, durationMinutes: 30, watchedAt: Date(timeIntervalSince1970: 1_600_000_000))
        let rewatch = BackupWatchEvent(tmdbShowId: 7, season: 1, episodeNumber: 1, durationMinutes: 30, watchedAt: Date(timeIntervalSince1970: 1_650_000_000))
        let show = BackupShow(tmdbId: 7, showName: "Rewatched", addedAt: .now, hiddenFromWatchNext: false)

        let result = store.restore(shows: [show], events: [firstWatch, rewatch])

        XCTAssertEqual(result.episodesImported, 2)
        XCTAssertEqual(result.duplicatesSkipped, 0)
        XCTAssertEqual(store.watchEvents.count, 2)
    }

    func testRestoreDoesNotOverwriteExistingShow() throws {
        store.addShow(tmdbId: 100, showName: "Severance")
        let incoming = BackupShow(tmdbId: 100, showName: "Renamed", addedAt: .distantPast, hiddenFromWatchNext: true)

        let result = store.restore(shows: [incoming], events: [])

        XCTAssertEqual(result.showsAdded, 0)
        let show = try XCTUnwrap(store.trackedShows.first)
        XCTAssertEqual(show.showName, "Severance")
        XCTAssertFalse(show.hiddenFromWatchNext)
    }
}
