import SwiftUI
import SwiftData

@main
struct Kami_Sam_WatchesApp: App {
    init() {
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TrackedShow.self, WatchEvent.self])
    }
}
