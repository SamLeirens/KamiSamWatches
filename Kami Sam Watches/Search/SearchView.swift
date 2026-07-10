import SwiftUI
import SwiftData

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var selectedShow: TMDBSearchResult?
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        _viewModel = State(initialValue: SearchViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .navigationDestination(item: $selectedShow) { show in
                    ShowDetailView(show: show, dataStore: dataStore)
                }
        }
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search TV shows")
        .onChange(of: viewModel.query) { viewModel.search() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Search Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            List(viewModel.results) { show in
                SearchResultRow(
                    show: show,
                    isTracking: viewModel.isTracking(show),
                    onTap: { selectedShow = show },
                    onToggleTracking: { viewModel.toggleTracking(show) }
                )
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Row

private struct SearchResultRow: View {
    let show: TMDBSearchResult
    let isTracking: Bool
    let onTap: () -> Void
    let onToggleTracking: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailImage(url: show.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w300\($0)") }, fallbackIcon: "tv")

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.headline)

                if let year = show.firstAirYear {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let overview = show.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }

                HStack {
                    if let rating = show.vote_average, rating > 0 {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Button(action: onToggleTracking) {
                        Label(isTracking ? "Tracking" : "Track", systemImage: isTracking ? "checkmark" : "plus")
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(isTracking ? .green : .accentColor)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

#Preview {
    let container = try! ModelContainer(for: TrackedShow.self, WatchEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SearchView(dataStore: DataStore(modelContext: container.mainContext))
}
