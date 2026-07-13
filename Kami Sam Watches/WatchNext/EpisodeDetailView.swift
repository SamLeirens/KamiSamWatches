import SwiftUI

@MainActor
@Observable
private final class EpisodeDetailViewModel {
    var tmdbEpisode: TMDBEpisode?
    var isLoading = false
    var errorMessage: String?

    private let tmdb: any TMDBService

    init(tmdb: any TMDBService = TMDB.shared) {
        self.tmdb = tmdb
    }

    func load(showId: Int, season: Int, episodeNumber: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await tmdb.fetchSeasonDetail(showId: showId, season: season)
            tmdbEpisode = detail.episodes.first { $0.episode_number == episodeNumber }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct EpisodeDetailView: View {
    let episode: Episode
    let dataStore: DataStore

    @State private var viewModel = EpisodeDetailViewModel()

    private var isWatched: Bool {
        dataStore.isWatched(showId: episode.tmdbShowId, season: episode.season, episode: episode.episodeNumber)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ThumbnailImage(url: episode.thumbnailURL, fallbackIcon: "play.rectangle.fill", size: .stillLarge)

                    Text(episode.showName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(episode.title)
                        .font(.title3)
                        .bold()

                    HStack(spacing: 6) {
                        Text(episode.label)
                        if let badge = episode.badge {
                            BadgeChip(badge)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button {
                        dataStore.toggleWatched(
                            showId: episode.tmdbShowId,
                            season: episode.season,
                            episode: episode.episodeNumber,
                            durationMinutes: viewModel.tmdbEpisode?.runtime ?? episode.durationMinutes
                        )
                    } label: {
                        Label(
                            isWatched ? "Watched" : "Mark Watched",
                            systemImage: isWatched ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(isWatched ? .green : .accentColor)
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if viewModel.isLoading {
                Section {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            } else if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            } else if let tmdbEpisode = viewModel.tmdbEpisode {
                if let overview = tmdbEpisode.overview, !overview.isEmpty {
                    Section("Overview") {
                        Text(overview)
                    }
                }

                Section {
                    if let airDate = TMDBFormat.parseDate(tmdbEpisode.air_date) {
                        LabeledContent("Air Date", value: airDate, format: .dateTime.day().month(.wide).year())
                    }
                    if let runtime = tmdbEpisode.runtime, runtime > 0 {
                        LabeledContent("Runtime") {
                            Text("\(runtime) min")
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    SeasonDetailView(
                        showId: episode.tmdbShowId,
                        showName: episode.showName,
                        seasonNumber: episode.season,
                        seasonName: nil,
                        dataStore: dataStore
                    )
                } label: {
                    Label("View Full Season", systemImage: "list.bullet")
                }
            }
        }
        .navigationTitle(episode.label)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(showId: episode.tmdbShowId, season: episode.season, episodeNumber: episode.episodeNumber)
        }
    }
}
