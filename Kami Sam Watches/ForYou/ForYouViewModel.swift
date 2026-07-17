import Foundation
import Observation

@Observable
final class ForYouViewModel {
    enum Stage {
        case picking
        case results
    }

    static let minSeeds = 3
    static let maxSeeds = 5

    var stage: Stage = .picking
    var selectedSeeds: [RecommendationSeed] = []
    var searchQuery = ""
    var searchResults: [TMDBSearchResult] = []
    var isSearching = false
    var recommendations: [ShowRecommendation] = []
    var isLoading = false
    var errorMessage: String?
    private(set) var posterURLs: [Int: URL] = [:]

    private let service: any RecommendationService
    private let tmdb: any TMDBService
    private let dataStore: DataStore
    private var searchTask: Task<Void, Never>?

    init(
        service: any RecommendationService = LiveRecommendationService(),
        tmdb: any TMDBService = TMDB.shared,
        dataStore: DataStore
    ) {
        self.service = service
        self.tmdb = tmdb
        self.dataStore = dataStore
    }

    // MARK: - Seed selection

    var trackedSeeds: [RecommendationSeed] {
        dataStore.trackedShows.map { RecommendationSeed(id: $0.tmdbId, name: $0.showName) }
    }

    /// Seeds picked via search that aren't tracked shows — kept visible in the picker list.
    var extraSelectedSeeds: [RecommendationSeed] {
        let trackedIds = Set(dataStore.trackedShows.map(\.tmdbId))
        return selectedSeeds.filter { !trackedIds.contains($0.id) }
    }

    var canRecommend: Bool {
        (Self.minSeeds...Self.maxSeeds).contains(selectedSeeds.count)
    }

    var canSelectMore: Bool {
        selectedSeeds.count < Self.maxSeeds
    }

    var selectionCountLabel: String {
        "\(selectedSeeds.count) of \(Self.maxSeeds) selected"
    }

    func isSelected(_ id: Int) -> Bool {
        selectedSeeds.contains { $0.id == id }
    }

    func toggleSeed(_ seed: RecommendationSeed, posterPath: String? = nil) {
        if let index = selectedSeeds.firstIndex(where: { $0.id == seed.id }) {
            selectedSeeds.remove(at: index)
        } else if canSelectMore {
            selectedSeeds.append(seed)
            if posterURLs[seed.id] == nil, let url = TMDBFormat.imageURL(path: posterPath) {
                posterURLs[seed.id] = url
            }
        }
    }

    func loadPosters() async {
        let missing = trackedSeeds.filter { posterURLs[$0.id] == nil }
        guard !missing.isEmpty else { return }
        let tmdb = self.tmdb
        let fetched = await withTaskGroup(of: (Int, URL?).self) { group in
            for seed in missing {
                group.addTask {
                    (seed.id, TMDBFormat.imageURL(path: (try? await tmdb.fetchShowDetail(id: seed.id))?.poster_path))
                }
            }
            var urls: [Int: URL] = [:]
            for await (id, url) in group {
                if let url { urls[id] = url }
            }
            return urls
        }
        posterURLs.merge(fetched) { _, new in new }
    }

    // MARK: - Search

    func search() {
        searchTask?.cancel()
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResults = []; return }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                searchResults = try await tmdb.searchShows(query: q)
            } catch {
                if !Task.isCancelled { searchResults = [] }
            }
            isSearching = false
        }
    }

    // MARK: - Recommendations

    func getRecommendations() async {
        guard canRecommend else { return }
        stage = .results
        isLoading = true
        errorMessage = nil
        do {
            let trackedIds = Set(dataStore.trackedShows.map(\.tmdbId))
            recommendations = try await service.recommendations(for: selectedSeeds, excluding: trackedIds)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func editPicks() {
        stage = .picking
    }

    // MARK: - Tracking

    func isTracking(_ id: Int) -> Bool {
        dataStore.trackedShows.contains { $0.tmdbId == id }
    }

    func toggleTracking(_ recommendation: ShowRecommendation) {
        if let existing = dataStore.trackedShows.first(where: { $0.tmdbId == recommendation.id }) {
            dataStore.removeShow(existing)
        } else {
            dataStore.addShow(tmdbId: recommendation.id, showName: recommendation.name)
        }
    }
}
