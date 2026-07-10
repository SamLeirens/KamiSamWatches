import SwiftUI
import SwiftData

@main
struct Kami_Sam_WatchesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TrackedShow.self, WatchEvent.self])
    }
}
