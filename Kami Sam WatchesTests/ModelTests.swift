import XCTest
@testable import Kami_Sam_Watches

final class ModelTests: XCTestCase {

    // MARK: - Episode.label

    func testEpisodeLabelFormat() {
        let ep = Episode(
            tmdbShowId: 1, showName: "Show", title: "Ep",
            season: 2, episodeNumber: 5,
            durationMinutes: 45, seasonEpisodeCount: 10,
            thumbnailURL: nil, airDate: nil, badge: nil, isWatched: false
        )
        XCTAssertEqual(ep.label, "S2 E5")
    }

    // MARK: - ReleaseKind.label

    func testReleaseKindLabelForEpisode() {
        let kind = ReleaseKind.episode(season: 3, episodeNumber: 7)
        XCTAssertEqual(kind.label, "S3 E7")
    }

    func testReleaseKindLabelForSeasonPremiere() {
        let kind = ReleaseKind.seasonPremiere(season: 4)
        XCTAssertEqual(kind.label, "Season 4 Premiere")
    }

    // MARK: - UpcomingRelease.releaseDateFormatted

    func testReleaseDateFormattedToday() {
        let release = makeRelease(daysFromNow: 0)
        XCTAssertEqual(release.releaseDateFormatted, "Today")
    }

    func testReleaseDateFormattedTomorrow() {
        let release = makeRelease(daysFromNow: 1)
        XCTAssertEqual(release.releaseDateFormatted, "Tomorrow")
    }

    func testReleaseDateFormattedInNDays() {
        let release = makeRelease(daysFromNow: 5)
        XCTAssertEqual(release.releaseDateFormatted, "in 5 days")
    }

    func testReleaseDateFormattedBoundaryAt7Days() {
        let release = makeRelease(daysFromNow: 7)
        XCTAssertEqual(release.releaseDateFormatted, "in 7 days")
    }

    func testReleaseDateFormattedAbbreviatedDateBeyond7Days() {
        let release = makeRelease(daysFromNow: 8)
        // Should not be "in N days" or "Today"/"Tomorrow"
        XCTAssertFalse(release.releaseDateFormatted.hasPrefix("in "))
        XCTAssertNotEqual(release.releaseDateFormatted, "Today")
        XCTAssertNotEqual(release.releaseDateFormatted, "Tomorrow")
    }

    // MARK: - EpisodeBadge raw values

    func testEpisodeBadgeRawValues() {
        XCTAssertEqual(EpisodeBadge.new.rawValue, "New")
        XCTAssertEqual(EpisodeBadge.latest.rawValue, "Latest")
        XCTAssertEqual(EpisodeBadge.premiere.rawValue, "Premiere")
    }

    // MARK: - Helper

    private func makeRelease(daysFromNow days: Int) -> UpcomingRelease {
        // Use noon to avoid edge cases when running near midnight
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        let noon = Calendar.current.date(from: components)!
        let date = Calendar.current.date(byAdding: .day, value: days, to: noon)!
        return UpcomingRelease(
            tmdbShowId: 1, showName: "Show", title: "Ep",
            kind: .episode(season: 1, episodeNumber: 1),
            overview: "", releaseDate: date, thumbnailURL: nil
        )
    }
}
