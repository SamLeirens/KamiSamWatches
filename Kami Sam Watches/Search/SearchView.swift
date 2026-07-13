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
            SearchContent(viewModel: viewModel, onSelect: { selectedShow = $0 })
                .navigationTitle("Search")
                .navigationDestination(item: $selectedShow) { show in
                    ShowDetailView(showId: show.id, showName: show.name, dataStore: dataStore)
                }
        }
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search TV shows")
        .onChange(of: viewModel.query) { viewModel.search() }
    }
}

private struct SearchContent: View {
    let viewModel: SearchViewModel
    let onSelect: (TMDBSearchResult) -> Void

    var body: some View {
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
                    onTap: { onSelect(show) },
                    onToggleTracking: { viewModel.toggleTracking(show) }
                )
                .cardRow()
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
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ThumbnailImage(url: TMDBFormat.imageURL(path: show.poster_path), fallbackIcon: "tv", size: .poster)

                VStack(alignment: .leading, spacing: 4) {
                    Text(show.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

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
                            Label {
                                Text(rating, format: .number.precision(.fractionLength(1)))
                            } icon: {
                                Image(systemName: "star.fill")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                        }

                        Spacer()

                        Button(action: onToggleTracking) {
                            Label(
                                isTracking ? "Tracking" : "Track",
                                systemImage: isTracking ? "checkmark" : "plus"
                            )
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(isTracking ? .green : .accentColor)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = try! ModelContainer(for: TrackedShow.self, WatchEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SearchView(dataStore: DataStore(modelContext: container.mainContext))
}
