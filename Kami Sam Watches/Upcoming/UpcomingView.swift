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
                    .cardRow()
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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DateBlock(release: release)

            VStack(alignment: .leading, spacing: 3) {
                Text(release.showName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(release.title)
                    .font(.headline)

                Text(release.kind.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !release.overview.isEmpty {
                    Text(release.overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    BadgeChip(label: release.kind.badgeLabel, color: release.kind.badgeColor)

                    Spacer()

                    Button("Notify Me") {
                        if let url = release.googleCalendarURL() {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct DateBlock: View {
    let release: UpcomingRelease

    private var isImminient: Bool {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: release.releaseDate)
        ).day ?? 0
        return days <= 1
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(release.releaseDayNumber)
                .font(.title2)
                .bold()
                .foregroundStyle(isImminient ? Color.accentColor : Color.primary)
            Text(release.releaseMonthAbbrev)
                .font(.caption2)
                .foregroundStyle(isImminient ? Color.accentColor : Color.secondary)
        }
        .frame(width: 44)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1), in: .rect(cornerRadius: 10))
    }
}

#Preview {
    let container = try! ModelContainer(for: TrackedShow.self, WatchEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    UpcomingView(dataStore: DataStore(modelContext: container.mainContext))
}
