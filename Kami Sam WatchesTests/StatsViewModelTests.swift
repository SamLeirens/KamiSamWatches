import XCTest
import SwiftData
@testable import Kami_Sam_Watches

@MainActor
final class StatsViewModelTests: XCTestCase {
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

    // MARK: - watchTimeLabel

    func testWatchTimeLabelZeroMinutes() {
        let vm = StatsViewModel(dataStore: store)
        XCTAssertEqual(vm.watchTimeLabel, "0m")
    }

    func testWatchTimeLabelMinutesOnly() {
        addEvent(minutes: 45)
        let vm = StatsViewModel(dataStore: store)
        XCTAssertEqual(vm.watchTimeLabel, "45m")
    }

    func testWatchTimeLabelHoursAndMinutes() {
        addEvent(minutes: 61)
        let vm = StatsViewModel(dataStore: store)
        XCTAssertEqual(vm.watchTimeLabel, "1h 1m")
    }

    func testWatchTimeLabelExactHourNoMinutes() {
        addEvent(minutes: 60)
        let vm = StatsViewModel(dataStore: store)
        XCTAssertEqual(vm.watchTimeLabel, "1h")
    }

    func testWatchTimeLabelMonthsAndDays() {
        addEvent(minutes: 30 * 24 * 60 + 2 * 24 * 60)  // 32 days
        let vm = StatsViewModel(dataStore: store)
        XCTAssertTrue(vm.watchTimeLabel.hasPrefix("1mo"))
    }

    // MARK: - monthlyActivity

    func testMonthlyActivityEmptyWhenNoEvents() {
        let vm = StatsViewModel(dataStore: store)
        XCTAssertTrue(vm.monthlyActivity.isEmpty)
    }

    func testMonthlyActivitySameMonthMerged() {
        let cal = Calendar.current
        let monthStart = cal.dateInterval(of: .month, for: .now)!.start
        let date1 = cal.date(byAdding: .day, value: 1, to: monthStart)!
        let date2 = cal.date(byAdding: .day, value: 2, to: monthStart)!

        let e1 = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: 45)
        e1.watchedAt = date1
        let e2 = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 2, durationMinutes: 45)
        e2.watchedAt = date2

        store.importData(shows: [(tmdbId: 1, name: "Show")], events: [e1, e2])
        let vm = StatsViewModel(dataStore: store)

        let thisMonth = vm.monthlyActivity.last
        XCTAssertEqual(thisMonth?.count, 2)
    }

    func testMonthlyActivitySortedAscending() {
        let cal = Calendar.current
        let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: .now)!
        let e = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: 45)
        e.watchedAt = twoMonthsAgo
        store.importData(shows: [(tmdbId: 1, name: "Show")], events: [e])
        let vm = StatsViewModel(dataStore: store)
        let dates = vm.monthlyActivity.map(\.month)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testMonthlyActivityReturns12Months() {
        let e = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: 45)
        store.importData(shows: [(tmdbId: 1, name: "Show")], events: [e])
        let vm = StatsViewModel(dataStore: store)
        XCTAssertEqual(vm.monthlyActivity.count, 12)
    }

    func testMonthlyActivityZeroFillsMissingMonths() {
        let cal = Calendar.current
        let elevenMonthsAgo = cal.date(byAdding: .month, value: -11, to: .now)!
        let e = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: 45)
        e.watchedAt = elevenMonthsAgo
        store.importData(shows: [(tmdbId: 1, name: "Show")], events: [e])
        let vm = StatsViewModel(dataStore: store)
        let totalCount = vm.monthlyActivity.map(\.count).reduce(0, +)
        XCTAssertEqual(totalCount, 1)
        XCTAssertEqual(vm.monthlyActivity.count, 12)
    }

    // MARK: - Helpers

    private func addEvent(minutes: Int) {
        let e = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: minutes)
        store.importData(shows: [], events: [e])
    }
}
