import Foundation
import Observation

@Observable
final class StatsViewModel {
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    var watchTimeLabel: String {
        let total = dataStore.totalWatchMinutes
        let mins = total % 60
        let totalHours = total / 60
        let hrs = totalHours % 24
        let totalDays = totalHours / 24
        let days = totalDays % 30
        let months = totalDays / 30

        var parts: [String] = []
        if months > 0 { parts.append("\(months)mo") }
        if days   > 0 { parts.append("\(days)d") }
        if hrs    > 0 { parts.append("\(hrs)h") }
        if mins   > 0 || parts.isEmpty { parts.append("\(mins)m") }
        return parts.joined(separator: " ")
    }

    var monthlyActivity: [MonthlyActivity] {
        let cal = Calendar.current
        var buckets: [Date: Int] = [:]
        for event in dataStore.watchEvents {
            if let monthStart = cal.dateInterval(of: .month, for: event.watchedAt)?.start {
                buckets[monthStart, default: 0] += 1
            }
        }

        guard !buckets.isEmpty else { return [] }

        let allMonths = monthStartsForLastYear(cal: cal)
        return allMonths.map { month in
            MonthlyActivity(month: month, count: buckets[month] ?? 0)
        }
    }

    func importSummaryMessage(_ summary: TVTimeImporter.Summary) -> String {
        var lines = [
            String(localized: "\(summary.episodesImported) episodes imported across \(summary.showsAdded) new shows.")
        ]
        if summary.duplicatesSkipped > 0 {
            lines.append(String(localized: "\(summary.duplicatesSkipped) duplicates skipped."))
        }
        if !summary.unresolvedShows.isEmpty {
            lines.append(String(localized: "Couldn't match: \(summary.unresolvedShows.joined(separator: ", "))"))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Private

    private func monthStartsForLastYear(cal: Calendar) -> [Date] {
        guard let now = cal.dateInterval(of: .month, for: .now)?.start else { return [] }
        return (0..<12).compactMap { cal.date(byAdding: .month, value: -11 + $0, to: now) }
    }
}
