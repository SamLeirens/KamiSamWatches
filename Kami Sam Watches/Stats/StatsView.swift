import SwiftUI
import UniformTypeIdentifiers

struct StatsView: View {
    let dataStore: DataStore

    @State private var showsFileImporter = false
    @State private var importPhase: TVTimeImporter.Phase?
    @State private var importSummary: TVTimeImporter.Summary?
    @State private var importError: String?

    private var hours: Int { dataStore.totalWatchMinutes / 60 }
    private var minutes: Int { dataStore.totalWatchMinutes % 60 }

    private var watchTimeLabel: String {
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
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
                        Section {
                            StatRow(label: "Episodes Watched", value: "\(dataStore.totalEpisodesWatched)")
                            StatRow(label: "Seasons Completed", value: "\(dataStore.totalSeasonsWatched)")
                            StatRow(label: "Shows Watched", value: "\(dataStore.totalShowsWatched)")
                            StatRow(label: "Total Watch Time", value: watchTimeLabel)
                        }

                        Section("History") {
                            ForEach(dataStore.watchEvents) { event in
                                WatchEventRow(event: event, showName: dataStore.showName(for: event.tmdbShowId))
                            }
                        }
                    }
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
                Text(summaryMessage(summary))
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

    private func summaryMessage(_ summary: TVTimeImporter.Summary) -> String {
        var lines = [
            String(localized: "\(summary.episodesImported) episodes imported across \(summary.showsAdded) new shows.")
        ]
        if summary.duplicatesSkipped > 0 {
            lines.append(String(localized: "\(summary.duplicatesSkipped) duplicates skipped."))
        }
        if !summary.unresolvedShows.isEmpty {
            lines.append(String(localized: "Couldn't match: \(summary.unresolvedShows.joined(separator: ", "))"))
        }
        return lines.joined(separator: "\n")
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

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
}

private struct WatchEventRow: View {
    let event: WatchEvent
    let showName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(showName)
                .font(.subheadline)
                .fontWeight(.medium)
            HStack {
                Text("S\(event.season) E\(event.episodeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(event.watchedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
