import SwiftUI
import SwiftData

@main
struct Kami_Sam_WatchesApp: App {
    // Explicit configuration keeps the store at the default location while
    // stating CloudKit intent: flip `.none` to `.automatic` once the iCloud
    // capability is enabled (requires a paid Apple Developer account).
    private let container: ModelContainer = {
        let schema = Schema([TrackedShow.self, WatchEvent.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
