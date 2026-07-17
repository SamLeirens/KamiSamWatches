import Foundation

protocol RecommendationService: Sendable {
    func recommendations(for seeds: [RecommendationSeed], excluding trackedIds: Set<Int>) async throws -> [ShowRecommendation]
}

// MARK: - Live

struct LiveRecommendationService: RecommendationService {
    private let tmdb: any TMDBService
    private let maxResults: Int

    init(tmdb: any TMDBService = TMDB.shared, maxResults: Int = 20) {
        self.tmdb = tmdb
        self.maxResults = maxResults
    }

    func recommendations(for seeds: [RecommendationSeed], excluding trackedIds: Set<Int>) async throws -> [ShowRecommendation] {
        let fetches = await fetchPerSeed(seeds)
        guard !fetches.isEmpty else { throw URLError(.badServerResponse) }
        return aggregate(fetches: fetches, seeds: seeds, trackedIds: trackedIds)
    }

    // MARK: Private

    private struct SeedFetch {
        let seed: RecommendationSeed
        let results: [TMDBRecommendedShow]
        let genres: [TMDBGenre]
    }

    private func fetchPerSeed(_ seeds: [RecommendationSeed]) async -> [SeedFetch] {
        await withTaskGroup(of: (Int, SeedFetch?).self) { group in
            for (index, seed) in seeds.enumerated() {
                group.addTask {
                    guard let results = try? await tmdb.fetchRecommendations(showId: seed.id) else {
                        return (index, nil)
                    }
                    // Genres enrich the reason line; a failure here shouldn't drop the seed
                    let genres = (try? await tmdb.fetchShowDetail(id: seed.id))?.genres ?? []
                    return (index, SeedFetch(seed: seed, results: results, genres: genres))
                }
            }
            var fetches: [(Int, SeedFetch)] = []
            for await (index, fetch) in group {
                if let fetch { fetches.append((index, fetch)) }
            }
            return fetches.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    private struct Candidate {
        var show: TMDBRecommendedShow
        var sourceShowNames: [String]
        var bestPosition: Int
    }

    private func aggregate(fetches: [SeedFetch], seeds: [RecommendationSeed], trackedIds: Set<Int>) -> [ShowRecommendation] {
        let seedIds = Set(seeds.map(\.id))
        var genreNames: [Int: String] = [:]
        var candidates: [Int: Candidate] = [:]

        for fetch in fetches {
            for genre in fetch.genres {
                genreNames[genre.id] = genre.name
            }
            for (position, show) in fetch.results.enumerated() {
                guard !trackedIds.contains(show.id), !seedIds.contains(show.id) else { continue }
                if var existing = candidates[show.id] {
                    existing.sourceShowNames.append(fetch.seed.name)
                    existing.bestPosition = min(existing.bestPosition, position)
                    candidates[show.id] = existing
                } else {
                    candidates[show.id] = Candidate(show: show, sourceShowNames: [fetch.seed.name], bestPosition: position)
                }
            }
        }

        let ranked = candidates.values.sorted { a, b in
            if a.sourceShowNames.count != b.sourceShowNames.count { return a.sourceShowNames.count > b.sourceShowNames.count }
            if a.bestPosition != b.bestPosition { return a.bestPosition < b.bestPosition }
            let voteA = a.show.vote_average ?? 0
            let voteB = b.show.vote_average ?? 0
            if voteA != voteB { return voteA > voteB }
            return a.show.name < b.show.name
        }

        return ranked.prefix(maxResults).map { candidate in
            ShowRecommendation(
                id: candidate.show.id,
                name: candidate.show.name,
                overview: candidate.show.overview,
                posterURL: TMDBFormat.imageURL(path: candidate.show.poster_path),
                firstAirYear: candidate.show.firstAirYear,
                voteAverage: candidate.show.vote_average,
                sourceShowNames: candidate.sourceShowNames,
                sharedGenres: (candidate.show.genre_ids ?? []).compactMap { genreNames[$0] }
            )
        }
    }
}
