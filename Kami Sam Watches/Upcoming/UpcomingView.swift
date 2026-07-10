import SwiftUI
import SwiftData

struct UpcomingView: View {
    @State private var viewModel: UpcomingViewModel

    init(dataStore: DataStore) {
        _viewModel = State(initialValue: UpcomingViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationStack {
            UpcomingContent(viewModel: viewModel)
                .navigationTitle("Upcoming")
        }
        .task { await viewModel.load() }
    }
}

private struct UpcomingContent: View {
    let viewModel: UpcomingViewModel

    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Couldn't Load Releases",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.releases.isEmpty {
            ContentUnavailableView(
                "Nothing Upcoming",
                systemImage: "calendar.badge.clock",
                description: Text("No upcoming releases found.")
            )
        } else {
            List(viewModel.releases) { release in
                UpcomingReleaseRow(release: release)
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }
}

// MARK: - Row

private struct UpcomingReleaseRow: View {
    let release: UpcomingRelease
    @Environment(\.openURL) private var openURL

    var badgeLabel: String {
        switch release.kind {
        case .seasonPremiere: return "Premiere"
        case .episode: return "New"
        }
    }

    var badgeColor: Color {
        switch release.kind {
        case .seasonPremiere: return .orange
        case .episode: return .accentColor
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailImage(url: release.thumbnailURL, fallbackIcon: "calendar.badge.clock")

            VStack(alignment: .leading, spacing: 4) {
                Text(release.showName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(release.title)
                    .font(.headline)

                Text(release.kind.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    BadgeChip(label: badgeLabel, color: badgeColor)

                    Spacer()

                    Label(release.releaseDateFormatted, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button("Notify Me") {
                        if let url = release.googleCalendarURL() {
                            openURL(url)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let container = try! ModelContainer(for: TrackedShow.self, WatchEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    UpcomingView(dataStore: DataStore(modelContext: container.mainContext))
}
