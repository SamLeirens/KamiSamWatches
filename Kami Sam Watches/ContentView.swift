import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataStore: DataStore?

    var body: some View {
        Group {
            if let dataStore {
                TabView {
                    Tab("Watch Next", systemImage: "play.circle.fill") {
                        WatchNextView(dataStore: dataStore)
                    }
                    Tab("Upcoming", systemImage: "calendar") {
                        UpcomingView(dataStore: dataStore)
                    }
                    Tab("Search", systemImage: "magnifyingglass") {
                        SearchView(dataStore: dataStore)
                    }
                    Tab("Stats", systemImage: "chart.bar.fill") {
                        StatsView(dataStore: dataStore)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if dataStore == nil {
                dataStore = DataStore(modelContext: modelContext)
            }
        }
    }
}
