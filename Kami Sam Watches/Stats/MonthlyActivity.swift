import Foundation

struct MonthlyActivity: Identifiable, Sendable {
    let month: Date
    let count: Int

    var id: Date { month }
}
