import SwiftUI

@Observable
private final class SeasonDetailViewModel {
    var episodes: [TMDBEpisode] = []
    var isLoading = false
    var errorMessage: String?

    private let tmdb: any TMDBService

    init(tmdb: any TMDBService = TMDB.shared) {
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

    var body: some View {
        SeasonDetailContent(
            showId: showId,
            showName: showName,
            seasonNumber: seasonNumber,
            dataStore: dataStore,
            viewModel: viewModel,
            onMarkAll: markAll
        )
        .navigationTitle(seasonTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(showId: showId, season: seasonNumber) }
    }

    private func markAll(watched: Bool) {
        let eps = viewModel.episodes.map { (number: $0.episode_number, durationMinutes: $0.runtime ?? 0) }
        dataStore.setWatched(showId: showId, season: seasonNumber, episodes: eps, watched: watched)
    }
}

private struct SeasonDetailContent: View {
    let showId: Int
    let showName: String
    let seasonNumber: Int
    let dataStore: DataStore
    let viewModel: SeasonDetailViewModel
    let onMarkAll: (Bool) -> Void

    private var watchedCount: Int {
        dataStore.watchedCount(showId: showId, season: seasonNumber)
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ShowDetailView(showId: showId, showName: showName, dataStore: dataStore)
                } label: {
                    Label("View Series", systemImage: "tv")
                }
            }

            if !viewModel.isLoading, !viewModel.episodes.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Button("Mark all watched") { onMarkAll(true) }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                        Button("Mark all unwatched") { onMarkAll(false) }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowSeparator(.hidden)
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
    }
}

// MARK: - Episode row

private struct EpisodeToggleRow: View {
    let episode: TMDBEpisode
    let isWatched: Bool
    let onToggle: () -> Void

    private var airDate: Date? {
        TMDBFormat.parseDate(episode.air_date)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ThumbnailImage(
                    url: TMDBFormat.imageURL(path: episode.still_path),
                    fallbackIcon: "play.rectangle",
                    size: .still
                )
                .overlay(alignment: .topLeading) {
                    if isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .background(.black.opacity(0.5), in: Circle())
                            .padding(4)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("E\(episode.episode_number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(episode.name)
                            .font(.body)
                            .foregroundStyle(isWatched ? .secondary : .primary)
                    }

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        if let date = airDate {
                            Text(date, format: .dateTime.day().month(.abbreviated).year())
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
        }
        .buttonStyle(.plain)
    }
}
