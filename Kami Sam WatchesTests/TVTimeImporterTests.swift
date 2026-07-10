import XCTest
import SwiftData
import ZIPFoundation
@testable import Kami_Sam_Watches

final class CSVParserTests: XCTestCase {
    func testParsesSimpleRows() {
        let rows = CSVParser.parse("a,b,c\n1,2,3")
        XCTAssertEqual(rows, [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testHandlesQuotedFieldsWithCommas() {
        let rows = CSVParser.parse("name,id\n\"Love, Death & Robots\",42")
        XCTAssertEqual(rows[1], ["Love, Death & Robots", "42"])
    }

    func testHandlesEscapedQuotes() {
        let rows = CSVParser.parse("name\n\"The \"\"Best\"\" Show\"")
        XCTAssertEqual(rows[1], ["The \"Best\" Show"])
    }

    func testHandlesCRLFAndTrailingNewline() {
        let rows = CSVParser.parse("a,b\r\n1,2\r\n")
        XCTAssertEqual(rows, [["a", "b"], ["1", "2"]])
    }

    func testParseRecordsKeysByHeader() {
        let records = CSVParser.parseRecords("id,name\n1,Foo\n2,Bar")
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0]["name"], "Foo")
        XCTAssertEqual(records[1]["id"], "2")
    }
}

final class TVTimeParserTests: XCTestCase {
    private let header = "ep_no,s_no,key,runtime,ep_id,created_at,user_id,s_id,gsi,bulk_type,total_series_runtime,updated_at,ep_watch_count,movie_watch_count,series_follow_count,total_movies_runtime,uuid,is_for_later,followed_at,is_followed,is_archived,most_recent_ep_watched,is_unitary,rewatch_count,is_special,movie_name,series_name,season_number,episode_number"

    func testParsesWatchAndRewatchRowsSkipsOthers() {
        let csv = """
        \(header)
        5,1,watch-episode-abc,2520,111,2023-04-16 19:24:06,1,413526,g,,,,,,,,,,,,,,true,,,,Treason,1,5
        3,1,rewatch-episode-def,3660,222,2024-11-25 20:00:53,1,338186,g,,,,,,,,,,,,,,,,,,Succession,1,3
        ,,user-profile-xyz,,,2022-01-01 00:00:00,1,,,,,,,,,,,,,,,,,,,,,,
        """
        let records = TVTimeParser.episodeRecords(fromCSV: csv)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].tvdbShowId, 413526)
        XCTAssertEqual(records[0].showName, "Treason")
        XCTAssertEqual(records[0].season, 1)
        XCTAssertEqual(records[0].episode, 5)
        XCTAssertEqual(records[0].runtimeMinutes, 42)
        XCTAssertEqual(records[1].showName, "Succession")
    }

    func testParsesTimestampAsUTC() {
        let date = TVTimeParser.dateFormatter.date(from: "2023-04-16 19:24:06")
        XCTAssertNotNil(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(calendar.component(.hour, from: date!), 19)
    }
}

@MainActor
final class DataStoreImportTests: XCTestCase {
    var store: Kami_Sam_Watches.DataStore!
    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: TrackedShow.self, WatchEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = Kami_Sam_Watches.DataStore(modelContext: container.mainContext)
        for show in store.trackedShows { store.removeShow(show) }
    }

    override func tearDown() async throws {
        store = nil
        container = nil
    }

    func testImportAddsShowsAndEvents() {
        let events = [
            WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 1, durationMinutes: 42, watchedAt: Date(timeIntervalSince1970: 1_000)),
            WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 2, durationMinutes: 42, watchedAt: Date(timeIntervalSince1970: 2_000)),
        ]
        let result = store.importData(shows: [(100, "Show A")], events: events)
        XCTAssertEqual(result.showsAdded, 1)
        XCTAssertEqual(result.episodesImported, 2)
        XCTAssertEqual(store.totalEpisodesWatched, 2)
        XCTAssertEqual(store.watchEvents.first?.watchedAt, Date(timeIntervalSince1970: 2_000))
    }

    func testImportSkipsEpisodesAlreadyWatched() {
        store.toggleWatched(showId: 100, season: 1, episode: 1, durationMinutes: 42)
        let events = [
            WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 1, durationMinutes: 42, watchedAt: Date(timeIntervalSince1970: 1_000))
        ]
        let result = store.importData(shows: [], events: events)
        XCTAssertEqual(result.episodesImported, 0)
        XCTAssertEqual(result.duplicatesSkipped, 1)
        XCTAssertEqual(store.totalEpisodesWatched, 1)
    }

    func testImportKeepsRewatchWithDifferentTimestamp() {
        let events = [
            WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 1, durationMinutes: 42, watchedAt: Date(timeIntervalSince1970: 1_000)),
            WatchEvent(tmdbShowId: 100, season: 1, episodeNumber: 1, durationMinutes: 42, watchedAt: Date(timeIntervalSince1970: 5_000)),
        ]
        let result = store.importData(shows: [], events: events)
        XCTAssertEqual(result.episodesImported, 2)
        XCTAssertEqual(result.duplicatesSkipped, 0)
    }

    func testImportDoesNotDuplicateExistingShow() {
        store.addShow(tmdbId: 100, showName: "Show A")
        let result = store.importData(shows: [(100, "Show A")], events: [])
        XCTAssertEqual(result.showsAdded, 0)
        XCTAssertEqual(store.trackedShows.count, 1)
    }
}

@MainActor
final class TVTimeImporterTests: XCTestCase {
    var store: Kami_Sam_Watches.DataStore!
    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: TrackedShow.self, WatchEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = Kami_Sam_Watches.DataStore(modelContext: container.mainContext)
        for show in store.trackedShows { store.removeShow(show) }
    }

    override func tearDown() async throws {
        store = nil
        container = nil
    }

    private func makeZip(csv: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dataDir = dir.appendingPathComponent("gdpr-data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        try csv.write(to: dataDir.appendingPathComponent("tracking-prod-records-v2.csv"), atomically: true, encoding: .utf8)
        let zipURL = dir.appendingPathComponent("export.zip")
        try FileManager.default.zipItem(at: dataDir, to: zipURL)
        return zipURL
    }

    func testEndToEndImportWithTVDBLookupAndSearchFallback() async throws {
        let header = "ep_no,s_no,key,runtime,ep_id,created_at,user_id,s_id,gsi,bulk_type,total_series_runtime,updated_at,ep_watch_count,movie_watch_count,series_follow_count,total_movies_runtime,uuid,is_for_later,followed_at,is_followed,is_archived,most_recent_ep_watched,is_unitary,rewatch_count,is_special,movie_name,series_name,season_number,episode_number"
        let csv = """
        \(header)
        1,1,watch-episode-a,2400,1,2023-01-01 10:00:00,1,111,g,,,,,,,,,,,,,,,,,,Show A,1,1
        2,1,watch-episode-b,2400,2,2023-01-02 10:00:00,1,222,g,,,,,,,,,,,,,,,,,,Show B,1,2
        3,1,watch-episode-c,2400,3,2023-01-03 10:00:00,1,333,g,,,,,,,,,,,,,,,,,,Show C,1,3
        """
        let zipURL = try makeZip(csv: csv)

        var mock = MockTMDBService()
        mock.findResults = [111: TMDBSearchResult(id: 9111, name: "Show A", overview: nil, first_air_date: nil, poster_path: nil, vote_average: nil)]
        // TVDB 222 falls back to name search; 333 resolves to nothing.
        mock.searchResults = [TMDBSearchResult(id: 9222, name: "Show B", overview: nil, first_air_date: nil, poster_path: nil, vote_average: nil)]

        let importer = TVTimeImporter(tmdb: mock)
        // Note: search fallback returns Show B's result for any query, so Show C also resolves here.
        let summary = try await importer.run(zipURL: zipURL, dataStore: store) { _ in }

        XCTAssertEqual(summary.showsAdded, 2) // 9111 and 9222 (C dedupes onto 9222)
        XCTAssertEqual(store.trackedShows.map(\.tmdbId).sorted(), [9111, 9222])
        XCTAssertTrue(store.isWatched(showId: 9111, season: 1, episode: 1))
        XCTAssertTrue(store.isWatched(showId: 9222, season: 1, episode: 2))
        XCTAssertEqual(store.watchEvents.first(where: { $0.tmdbShowId == 9111 })?.durationMinutes, 40)
    }

    // Exercises unzip + parse on a real TV Time GDPR export when present on this machine.
    func testRealExportParsesIfAvailable() async throws {
        let zipURL = URL(fileURLWithPath: "/Users/sam.leirens/Downloads/tvtime-export.zip")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: zipURL.path), "Real export not present")

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }
        try FileManager.default.unzipItem(at: zipURL, to: workDir)

        let csvURL = workDir.appendingPathComponent("gdpr-data/tracking-prod-records-v2.csv")
        let text = try String(contentsOf: csvURL, encoding: .utf8)
        let records = TVTimeParser.episodeRecords(fromCSV: text)

        XCTAssertGreaterThan(records.count, 6000)
        XCTAssertGreaterThan(Set(records.map(\.tvdbShowId)).count, 200)
        XCTAssertTrue(records.allSatisfy { $0.season >= 0 && $0.episode > 0 })
    }

    func testMissingCSVThrows() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let emptyDir = dir.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let zipURL = dir.appendingPathComponent("empty.zip")
        try FileManager.default.zipItem(at: emptyDir, to: zipURL)

        let importer = TVTimeImporter(tmdb: MockTMDBService())
        do {
            _ = try await importer.run(zipURL: zipURL, dataStore: store) { _ in }
            XCTFail("Expected csvNotFound")
        } catch let error as TVTimeImporter.ImportError {
            XCTAssertEqual(error, .csvNotFound)
        }
    }
}
