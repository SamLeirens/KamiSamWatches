import SwiftUI

@Observable
private final class SeasonDetailViewModel {
    var episodes: [TMDBEpisode] = []
    var isLoading = false
    var errorMessage: String?

    private let tmdb: any TMDBService

    init(tmdb: any TMDBService = LiveTMDBService()) {
        self.tmdb = tmdb
    }

    func load(showId: Int, season: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await tmdb.fetchSeasonDetail(showId: showId, season: season)
            episodes = detail.episodes.sorted { $0.episode_number < $1.episode_number }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct SeasonDetailView: View {
    let showId: Int
    let showName: String
    let seasonNumber: Int
    let seasonName: String?
    let dataStore: DataStore

    @State private var viewModel = SeasonDetailViewModel()

    private var seasonTitle: String { seasonName ?? "Season \(seasonNumber)" }

    private var watchedCount: Int {
        dataStore.watchEvents.filter { $0.tmdbShowId == showId && $0.season == seasonNumber }.count
    }

    var body: some View {
        List {
            if !viewModel.isLoading, !viewModel.episodes.isEmpty {
                Section {
                    Button("Mark All Watched") { markAll(watched: true) }
                        .frame(maxWidth: .infinity)
                    Button("Mark All Unwatched") { markAll(watched: false) }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }

                Section("\(watchedCount) of \(viewModel.episodes.count) watched") {
                    ForEach(viewModel.episodes, id: \.episode_number) { ep in
                        EpisodeToggleRow(
                            episode: ep,
                            isWatched: dataStore.isWatched(showId: showId, season: seasonNumber, episode: ep.episode_number)
                        ) {
                            dataStore.toggleWatched(
                                showId: showId,
                                season: seasonNumber,
                                episode: ep.episode_number,
                                durationMinutes: ep.runtime ?? 0
                            )
                        }
                    }
                }
            } else if viewModel.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .navigationTitle(seasonTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(showId: showId, season: seasonNumber) }
    }

    private func markAll(watched: Bool) {
        for ep in viewModel.episodes {
            let currently = dataStore.isWatched(showId: showId, season: seasonNumber, episode: ep.episode_number)
            if watched != currently {
                dataStore.toggleWatched(
                    showId: showId,
                    season: seasonNumber,
                    episode: ep.episode_number,
                    durationMinutes: ep.runtime ?? 0
                )
            }
        }
    }
}

// MARK: - Episode row

private struct EpisodeToggleRow: View {
    let episode: TMDBEpisode
    let isWatched: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isWatched ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("E\(episode.episode_number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(episode.name)
                        .font(.body)
                        .foregroundStyle(isWatched ? .secondary : .primary)
                }

                HStack(spacing: 8) {
                    if let dateStr = episode.air_date {
                        Text(dateStr)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let runtime = episode.runtime, runtime > 0 {
                        Text("· \(runtime) min")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
