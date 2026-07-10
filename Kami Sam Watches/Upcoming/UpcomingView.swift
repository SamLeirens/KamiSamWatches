import SwiftUI
import SwiftData

struct UpcomingView: View {
    @State private var viewModel: UpcomingViewModel

    init(dataStore: DataStore) {
        _viewModel = State(initialValue: UpcomingViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Upcoming")
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
        }
    }
}

// MARK: - Row

private struct UpcomingReleaseRow: View {
    let release: UpcomingRelease

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

                    Button("Notify Me") {}
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
