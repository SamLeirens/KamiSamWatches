import SwiftUI
import SwiftData

struct WatchNextView: View {
    let dataStore: DataStore

    @State private var viewModel: WatchNextViewModel

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        _viewModel = State(initialValue: WatchNextViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationStack {
            WatchNextContent(viewModel: viewModel, dataStore: dataStore)
                .toolbar(.hidden, for: .navigationBar)
        }
        .task { await viewModel.load() }
    }
}

private struct WatchNextContent: View {
    @Bindable var viewModel: WatchNextViewModel
    let dataStore: DataStore

    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Couldn't Load Episodes",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.episodes.isEmpty {
            ContentUnavailableView(
                "All Caught Up",
                systemImage: "checkmark.circle",
                description: Text("No episodes left to watch.")
            )
        } else {
            List {
                ForEach(viewModel.filteredEpisodes) { episode in
                    ZStack {
                        NavigationLink {
                            EpisodeDetailView(episode: episode, dataStore: dataStore)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)

                        EpisodeRow(episode: episode) {
                            Task { await viewModel.markWatched(episode) }
                        }
                    }
                    .cardRow()
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewModel.hideShow(tmdbId: episode.tmdbShowId)
                        } label: {
                            Label(String(localized: "Hide"), systemImage: "eye.slash")
                        }
                        .tint(.orange)
                    }
                }

                if viewModel.filteredEpisodes.isEmpty {
                    ContentUnavailableView(
                        "Nothing here",
                        systemImage: "tv",
                        description: Text("No episodes match the current filter.")
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
            .safeAreaInset(edge: .top) {
                FilterChipRow(filter: $viewModel.filter)
            }
        }
    }
}

// MARK: - Filter chips

private struct FilterChipRow: View {
    @Binding var filter: WatchNextFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WatchNextFilter.allCases) { option in
                    FilterChip(label: option.rawValue, isSelected: filter == option) {
                        filter = option
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .bold()
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Theme.cardBackground, in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct EpisodeRow: View {
    let episode: Episode
    let onMarkWatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ThumbnailImage(url: episode.thumbnailURL, fallbackIcon: "play.rectangle.fill")

                VStack(alignment: .leading, spacing: 3) {
                    Text(episode.showName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(episode.title)
                        .font(.headline)
                        .strikethrough(episode.isWatched)
                        .foregroundStyle(episode.isWatched ? .secondary : .primary)

                    HStack(spacing: 4) {
                        Text(episode.label)
                        if episode.durationMinutes > 0 {
                            Text("·")
                            Text("\(episode.durationMinutes) min")
                        }
                        if let date = episode.airDate {
                            Text("·")
                            Text(date, format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let progress = episode.seasonProgress {
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                    if episode.seasonEpisodeCount > 0 {
                        Text("\(episode.episodeNumber - 1) of \(episode.seasonEpisodeCount) this season")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack {
                if let badge = episode.badge {
                    BadgeChip(badge)
                }

                Spacer()

                if !episode.isWatched {
                    Button("Mark Watched", action: onMarkWatched)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                } else {
                    Label("Watched", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .opacity(episode.isWatched ? 0.5 : 1)
    }
}

#Preview {
    let container = try! ModelContainer(for: TrackedShow.self, WatchEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    WatchNextView(dataStore: DataStore(modelContext: container.mainContext))
}
