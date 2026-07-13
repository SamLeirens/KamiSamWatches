import XCTest
@testable import Kami_Sam_Watches

final class UpcomingReleaseCalendarTests: XCTestCase {

    private func makeRelease(
        kind: ReleaseKind = .episode(season: 2, episodeNumber: 5),
        showName: String = "Dark Matter",
        title: String = "The Corridor",
        overview: String = "Jason faces a choice.",
        daysFromNow: Int = 7
    ) -> UpcomingRelease {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return UpcomingRelease(
            tmdbShowId: 1,
            showName: showName,
            title: title,
            kind: kind,
            overview: overview,
            releaseDate: date,
            posterURL: nil
        )
    }

    func testURLSchemeAndHost() {
        let url = makeRelease().googleCalendarURL()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "calendar.google.com")
    }

    func testActionIsTemplate() {
        let url = makeRelease().googleCalendarURL()!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first(where: { $0.name == "action" })?.value, "TEMPLATE")
    }

    func testTitleContainsShowAndEpisodeName() {
        let url = makeRelease(showName: "Dark Matter", title: "The Corridor").googleCalendarURL()!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let text = items.first(where: { $0.name == "text" })?.value ?? ""
        XCTAssertTrue(text.contains("Dark Matter"))
        XCTAssertTrue(text.contains("The Corridor"))
    }

    func testDatesSpanOneDay() throws {
        let release = makeRelease(daysFromNow: 10)
        let url = try XCTUnwrap(release.googleCalendarURL())
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let dates = try XCTUnwrap(items.first(where: { $0.name == "dates" })?.value)
        let parts = dates.split(separator: "/")
        XCTAssertEqual(parts.count, 2)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let start = try XCTUnwrap(formatter.date(from: String(parts[0])))
        let end   = try XCTUnwrap(formatter.date(from: String(parts[1])))
        let diff  = Calendar.current.dateComponents([.day], from: start, to: end).day
        XCTAssertEqual(diff, 1)
    }

    func testDetailsContainsOverview() {
        let url = makeRelease(overview: "Jason faces a choice.").googleCalendarURL()!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let details = items.first(where: { $0.name == "details" })?.value ?? ""
        XCTAssertTrue(details.contains("Jason faces a choice."))
    }

    func testDetailsOmitsOverviewWhenEmpty() {
        let url = makeRelease(overview: "").googleCalendarURL()!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let details = items.first(where: { $0.name == "details" })?.value ?? ""
        XCTAssertFalse(details.contains("\n\n"))
    }

    func testSeasonPremiereKindLabelInDetails() {
        let url = makeRelease(kind: .seasonPremiere(season: 3)).googleCalendarURL()!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let details = items.first(where: { $0.name == "details" })?.value ?? ""
        XCTAssertTrue(details.hasPrefix("Season 3 Premiere"))
    }
}
