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
            content
                .navigationTitle("Watch Next")
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
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
                ForEach(viewModel.episodes) { episode in
                    NavigationLink {
                        EpisodeDetailView(episode: episode, dataStore: dataStore)
                    } label: {
                        EpisodeRow(episode: episode) {
                            Task { await viewModel.markWatched(episode) }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await viewModel.hideShow(tmdbId: episode.tmdbShowId) }
                        } label: {
                            Label(String(localized: "Hide"), systemImage: "eye.slash")
                        }
                        .tint(.orange)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Row

private struct EpisodeRow: View {
    let episode: Episode
    let onMarkWatched: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailImage(url: episode.thumbnailURL, fallbackIcon: "play.rectangle.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.showName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(episode.title)
                    .font(.headline)
                    .strikethrough(episode.isWatched)
                    .foregroundStyle(episode.isWatched ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(episode.label)
                    if episode.seasonEpisodeCount > 0 {
                        Text("·")
                        Text("of \(episode.seasonEpisodeCount) this season")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack {
                    if let badge = episode.badge {
                        BadgeChip(label: badge.rawValue)
                    }

                    Spacer()

                    if !episode.isWatched {
                        Button("Mark Watched", action: onMarkWatched)
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    } else {
                        Label("Watched", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .opacity(episode.isWatched ? 0.5 : 1)
    }
}

// MARK: - Thumbnail

struct ThumbnailImage: View {
    let url: URL?
    let fallbackIcon: String

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: fallbackIcon)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 56)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Badge

struct BadgeChip: View {
    let label: String
    var color: Color = .accentColor

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    let container = try! ModelContainer(for: TrackedShow.self, WatchEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    WatchNextView(dataStore: DataStore(modelContext: container.mainContext))
}
