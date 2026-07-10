import Foundation

actor TMDBCache {
    private struct Entry {
        let value: any Sendable
        let expiresAt: Date
    }

    private var store: [String: Entry] = [:]

    func get<T: Sendable>(key: String) -> T? {
        guard let entry = store[key], entry.expiresAt > .now else { return nil }
        return entry.value as? T
    }

    func set<T: Sendable>(_ value: T, key: String, ttl: TimeInterval) {
        store[key] = Entry(value: value, expiresAt: .now.addingTimeInterval(ttl))
    }

    func removeAll() {
        store.removeAll()
    }
}

enum TMDB {
    private static let cache = TMDBCache()
    static let shared: any TMDBService = CachingTMDBService(base: LiveTMDBService(), cache: cache)

    static func clearCache() async {
        await cache.removeAll()
    }
}
