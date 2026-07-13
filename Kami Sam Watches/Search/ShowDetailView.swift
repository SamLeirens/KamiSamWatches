import SwiftUI

@Observable
private final class ShowDetailViewModel {
    var detail: TMDBShowDetail?
    var isLoading = false
    var errorMessage: String?

    private let tmdb: any TMDBService
    let showId: Int
    let showName: String

    init(showId: Int, showName: String, tmdb: any TMDBService = TMDB.shared) {
        self.showId = showId
        self.showName = showName
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

    var backdropURL: URL? {
        TMDBFormat.imageURL(path: detail?.backdrop_path, size: .w780)
    }

    var posterURL: URL? {
        TMDBFormat.imageURL(path: detail?.poster_path)
    }

    var firstAirYear: String? {
        detail?.firstAirYear
    }
}

struct ShowDetailView: View {
    let showId: Int
    let showName: String
    let dataStore: DataStore

    @State private var viewModel: ShowDetailViewModel

    init(showId: Int, showName: String, dataStore: DataStore) {
        self.showId = showId
        self.showName = showName
        self.dataStore = dataStore
        _viewModel = State(initialValue: ShowDetailViewModel(showId: showId, showName: showName))
    }

    private var isTracking: Bool {
        dataStore.trackedShows.contains(where: { $0.tmdbId == showId })
    }

    var body: some View {
        List {
            ShowHeaderSection(
                viewModel: viewModel,
                isTracking: isTracking,
                onToggle: toggleTracking
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

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
                                showId: showId,
                                showName: viewModel.showName,
                                seasonNumber: season.season_number,
                                seasonName: season.name,
                                dataStore: dataStore
                            )
                        } label: {
                            SeasonRow(season: season, showId: showId, dataStore: dataStore)
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
        if let existing = dataStore.trackedShows.first(where: { $0.tmdbId == showId }) {
            dataStore.removeShow(existing)
        } else {
            dataStore.addShow(tmdbId: showId, showName: showName)
        }
    }
}

// MARK: - Header

private struct ShowHeaderSection: View {
    let viewModel: ShowDetailViewModel
    let isTracking: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                ThumbnailImage(url: viewModel.backdropURL, fallbackIcon: "photo", size: .stillLarge)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }

                ThumbnailImage(url: viewModel.posterURL, fallbackIcon: "tv", size: .posterLarge)
                    .padding(.leading, 16)
                    .padding(.bottom, -40)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.showName)
                        .font(.title2)
                        .bold()
                        .padding(.top, 48)

                    if let year = viewModel.firstAirYear {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onToggle) {
                    Label(
                        isTracking ? "Tracking" : "Add to My Shows",
                        systemImage: isTracking ? "checkmark.circle.fill" : "plus.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(isTracking ? .green : .accentColor)
                .padding(.top, 44)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if let overview = viewModel.detail?.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Season row

private struct SeasonRow: View {
    let season: TMDBShowDetail.Season
    let showId: Int
    let dataStore: DataStore

    private var watchedCount: Int {
        dataStore.watchedCount(showId: showId, season: season.season_number)
    }

    private var progress: Double? {
        dataStore.seasonProgress(showId: showId, season: season.season_number, totalEpisodes: season.episode_count)
    }

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailImage(url: TMDBFormat.imageURL(path: season.poster_path), fallbackIcon: "photo", size: .poster)

            VStack(alignment: .leading, spacing: 4) {
                Text(season.name ?? "Season \(season.season_number)")
                    .font(.body)

                if let total = season.episode_count {
                    HStack(spacing: 6) {
                        Text("\(watchedCount)/\(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if watchedCount >= total && watchedCount > 0 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    if let p = progress {
                        ProgressView(value: p)
                            .tint(watchedCount >= total ? .green : .accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
