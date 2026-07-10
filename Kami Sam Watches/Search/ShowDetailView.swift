import SwiftUI

@Observable
private final class ShowDetailViewModel {
    var detail: TMDBShowDetail?
    var isLoading = false
    var errorMessage: String?

    private let tmdb: any TMDBService
    let showId: Int
    let showName: String
    let posterURL: URL?

    init(show: TMDBSearchResult, tmdb: any TMDBService = LiveTMDBService()) {
        self.showId = show.id
        self.showName = show.name
        self.posterURL = show.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w300\($0)") }
        self.tmdb = tmdb
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await tmdb.fetchShowDetail(id: showId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var mainSeasons: [TMDBShowDetail.Season] {
        (detail?.seasons ?? []).filter { $0.season_number > 0 }.sorted { $0.season_number < $1.season_number }
    }
}

struct ShowDetailView: View {
    let show: TMDBSearchResult
    let dataStore: DataStore

    @State private var viewModel: ShowDetailViewModel

    init(show: TMDBSearchResult, dataStore: DataStore) {
        self.show = show
        self.dataStore = dataStore
        _viewModel = State(initialValue: ShowDetailViewModel(show: show))
    }

    private var isTracking: Bool {
        dataStore.trackedShows.contains(where: { $0.tmdbId == show.id })
    }

    var body: some View {
        List {
            // Header
            Section {
                HStack(alignment: .top, spacing: 16) {
                    ThumbnailImage(url: viewModel.posterURL, fallbackIcon: "tv")
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.showName)
                            .font(.title2.bold())

                        if let year = show.firstAirYear {
                            Text(year)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Button(action: { toggleTracking() }) {
                            Label(
                                isTracking ? "Tracking" : "Add to My Shows",
                                systemImage: isTracking ? "checkmark.circle.fill" : "plus.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isTracking ? .green : .accentColor)
                    }
                }
                .padding(.vertical, 4)

                if let overview = viewModel.detail?.overview ?? show.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Seasons
            if viewModel.isLoading {
                Section {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            } else if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            } else {
                Section("Seasons") {
                    ForEach(viewModel.mainSeasons, id: \.season_number) { season in
                        NavigationLink {
                            SeasonDetailView(
                                showId: show.id,
                                showName: viewModel.showName,
                                seasonNumber: season.season_number,
                                seasonName: season.name,
                                dataStore: dataStore
                            )
                        } label: {
                            SeasonRow(season: season, showId: show.id, dataStore: dataStore)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.showName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func toggleTracking() {
        if let existing = dataStore.trackedShows.first(where: { $0.tmdbId == show.id }) {
            dataStore.removeShow(existing)
        } else {
            dataStore.addShow(tmdbId: show.id, showName: show.name)
        }
    }
}

// MARK: - Season row

private struct SeasonRow: View {
    let season: TMDBShowDetail.Season
    let showId: Int
    let dataStore: DataStore

    private var watchedCount: Int {
        dataStore.watchEvents.filter { $0.tmdbShowId == showId && $0.season == season.season_number }.count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(season.name ?? "Season \(season.season_number)")
                    .font(.body)

                if let total = season.episode_count {
                    Text(watchedCount > 0 ? "\(watchedCount) / \(total) watched" : "\(total) episodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if watchedCount > 0, let total = season.episode_count, watchedCount >= total {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}
