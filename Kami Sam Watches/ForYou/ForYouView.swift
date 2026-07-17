import SwiftUI
import SwiftData

struct ForYouView: View {
    @State private var viewModel: ForYouViewModel
    @State private var selectedRecommendation: ShowRecommendation?
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        _viewModel = State(initialValue: ForYouViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.stage {
                case .picking:
                    SeedPickerContent(viewModel: viewModel)
                case .results:
                    RecommendationsContent(viewModel: viewModel, onSelect: { selectedRecommendation = $0 })
                }
            }
            .navigationTitle("For You")
            .navigationDestination(item: $selectedRecommendation) { recommendation in
                ShowDetailView(showId: recommendation.id, showName: recommendation.name, dataStore: dataStore)
            }
            .toolbar {
                if viewModel.stage == .results {
                    Button("Edit Picks", systemImage: "slider.horizontal.3") {
                        viewModel.editPicks()
                    }
                }
            }
        }
        .task { await viewModel.loadPosters() }
    }
}

// MARK: - Seed picker

private struct SeedPickerContent: View {
    @Bindable var viewModel: ForYouViewModel

    private var isShowingSearchResults: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        List {
            if isShowingSearchResults {
                ForEach(viewModel.searchResults) { show in
                    SeedRow(
                        name: show.name,
                        year: show.firstAirYear,
                        posterURL: TMDBFormat.imageURL(path: show.poster_path),
                        isSelected: viewModel.isSelected(show.id),
                        isDimmed: !viewModel.canSelectMore && !viewModel.isSelected(show.id),
                        onToggle: {
                            viewModel.toggleSeed(RecommendationSeed(id: show.id, name: show.name), posterPath: show.poster_path)
                        }
                    )
                    .cardRow()
                }
            } else {
                Section {
                    ForEach(viewModel.extraSelectedSeeds + viewModel.trackedSeeds) { seed in
                        SeedRow(
                            name: seed.name,
                            year: nil,
                            posterURL: viewModel.posterURLs[seed.id],
                            isSelected: viewModel.isSelected(seed.id),
                            isDimmed: !viewModel.canSelectMore && !viewModel.isSelected(seed.id),
                            onToggle: { viewModel.toggleSeed(seed) }
                        )
                        .cardRow()
                    }
                } header: {
                    HStack {
                        Text("Pick \(ForYouViewModel.minSeeds)–\(ForYouViewModel.maxSeeds) shows you love")
                        Spacer()
                        Text(viewModel.selectionCountLabel)
                            .foregroundStyle(viewModel.canRecommend ? Color.accentColor : .secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if isShowingSearchResults && viewModel.searchResults.isEmpty && !viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchQuery)
            } else if !isShowingSearchResults && viewModel.trackedSeeds.isEmpty && viewModel.extraSelectedSeeds.isEmpty {
                ContentUnavailableView(
                    "No Shows Yet",
                    systemImage: "sparkles",
                    description: Text("Search above to pick shows you love, and we'll recommend what to watch next.")
                )
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Add any show as a pick"
        )
        .onChange(of: viewModel.searchQuery) { viewModel.search() }
        .safeAreaInset(edge: .bottom) {
            RecommendButton(viewModel: viewModel)
        }
    }
}

private struct RecommendButton: View {
    let viewModel: ForYouViewModel

    var body: some View {
        Button {
            Task { await viewModel.getRecommendations() }
        } label: {
            Label("Get Recommendations", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canRecommend)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct SeedRow: View {
    let name: String
    let year: String?
    let posterURL: URL?
    let isSelected: Bool
    let isDimmed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ThumbnailImage(url: posterURL, fallbackIcon: "tv", size: .poster)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.4 : 1)
        .disabled(isDimmed)
    }
}

// MARK: - Results

private struct RecommendationsContent: View {
    let viewModel: ForYouViewModel
    let onSelect: (ShowRecommendation) -> Void

    var body: some View {
        if viewModel.isLoading {
            ProgressView("Finding shows for you…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Recommendations Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.recommendations.isEmpty {
            ContentUnavailableView(
                "No Recommendations",
                systemImage: "sparkles",
                description: Text("Try different picks — we couldn't find anything new based on these shows.")
            )
        } else {
            List(viewModel.recommendations) { recommendation in
                RecommendationRow(
                    recommendation: recommendation,
                    isTracking: viewModel.isTracking(recommendation.id),
                    onTap: { onSelect(recommendation) },
                    onToggleTracking: { viewModel.toggleTracking(recommendation) }
                )
                .cardRow()
            }
            .listStyle(.plain)
        }
    }
}

private struct RecommendationRow: View {
    let recommendation: ShowRecommendation
    let isTracking: Bool
    let onTap: () -> Void
    let onToggleTracking: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ThumbnailImage(url: recommendation.posterURL, fallbackIcon: "tv", size: .poster)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let year = recommendation.firstAirYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label(recommendation.reasonText, systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 1)

                    if let genres = recommendation.sharedGenresLabel {
                        Text(genres)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        if let rating = recommendation.voteAverage, rating > 0 {
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
    ForYouView(dataStore: DataStore(modelContext: container.mainContext))
}
