import Foundation

/// A show the user picked as input for recommendations.
struct RecommendationSeed: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct ShowRecommendation: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let posterURL: URL?
    let firstAirYear: String?
    let voteAverage: Double?
    let sourceShowNames: [String]
    let sharedGenres: [String]

    var reasonText: String {
        guard !sourceShowNames.isEmpty else { return String(localized: "Recommended for you") }
        return String(localized: "Because you watch \(sourceShowNames.formatted(.list(type: .and)))")
    }

    var sharedGenresLabel: String? {
        sharedGenres.isEmpty ? nil : sharedGenres.joined(separator: " · ")
    }
}
