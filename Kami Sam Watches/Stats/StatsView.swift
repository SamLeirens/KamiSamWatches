import SwiftUI
import Charts
import UniformTypeIdentifiers

struct StatsView: View {
    let dataStore: DataStore

    @State private var viewModel: StatsViewModel
    @State private var showsFileImporter = false
    @State private var importPhase: TVTimeImporter.Phase?
    @State private var importSummary: TVTimeImporter.Summary?
    @State private var importError: String?

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        _viewModel = State(initialValue: StatsViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.totalEpisodesWatched == 0 {
                    ContentUnavailableView(
                        "No Watch History Yet",
                        systemImage: "chart.bar",
                        description: Text("Mark episodes as watched to see your stats.")
                    )
                } else {
                    List {
                        MetricTileGrid(dataStore: dataStore, viewModel: viewModel)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        ActivityChartSection(activity: viewModel.monthlyActivity)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        Section("History") {
                            ForEach(dataStore.watchEvents) { event in
                                WatchEventRow(event: event, showName: dataStore.showName(for: event.tmdbShowId))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showsFileImporter = true
                        } label: {
                            Label("Import from TV Time", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(importPhase != nil)
                }
            }
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.zip]) { result in
                switch result {
                case .success(let url):
                    startImport(from: url)
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .overlay {
                if let phase = importPhase {
                    ImportProgressOverlay(phase: phase)
                }
            }
            .alert(
                String(localized: "Import Complete"),
                isPresented: Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } }),
                presenting: importSummary
            ) { _ in
                Button(String(localized: "OK"), role: .cancel) {}
            } message: { summary in
                Text(viewModel.importSummaryMessage(summary))
            }
            .alert(
                String(localized: "Import Failed"),
                isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
            ) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func startImport(from url: URL) {
        importPhase = .readingArchive
        Task {
            defer { importPhase = nil }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let importer = TVTimeImporter(tmdb: TMDB.shared)
                importSummary = try await importer.run(zipURL: url, dataStore: dataStore) { phase in
                    importPhase = phase
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

}

// MARK: - Metric tiles

private struct MetricTileGrid: View {
    let dataStore: DataStore
    let viewModel: StatsViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(icon: "play.circle", value: "\(dataStore.totalEpisodesWatched)", label: "Episodes")
            MetricTile(icon: "square.stack", value: "\(dataStore.totalSeasonsWatched)", label: "Seasons")
            MetricTile(icon: "list.bullet.below.rectangle", value: "\(dataStore.totalShowsWatched)", label: "Shows")
            MetricTile(icon: "clock", value: viewModel.watchTimeLabel, label: "Watch time")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

private struct MetricTile: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.title3)

            Text(value)
                .font(.title2)
                .bold()
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cardCornerRadius))
    }
}

// MARK: - Activity chart

private struct ActivityChartSection: View {
    let activity: [MonthlyActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Episodes per month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Chart(activity) { item in
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Episodes", item.count)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 2)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 140)
        }
        .padding(14)
        .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cardCornerRadius))
        .padding(.bottom, 8)
    }
}

// MARK: - Subviews

private struct ImportProgressOverlay: View {
    let phase: TVTimeImporter.Phase

    private var label: String {
        switch phase {
        case .readingArchive:
            return String(localized: "Reading export…")
        case .matchingShows(let done, let total):
            return String(localized: "Matching shows (\(done)/\(total))…")
        case .saving:
            return String(localized: "Saving…")
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WatchEventRow: View {
    let event: WatchEvent
    let showName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(showName)
                    .font(.subheadline)
                    .bold()
                Text("S\(event.season) E\(event.episodeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.watchedAt, format: .dateTime.day().month(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
