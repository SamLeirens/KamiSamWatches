---
name: add-feature
description: Add a new feature or tab to Kami Sam Watches following the established MVVM + service-protocol pattern. Use when asked to add a new screen, tab, or user-facing capability to the app.
---

# Add a feature to Kami Sam Watches

Follow the existing pattern exactly — every current tab (WatchNext, Upcoming, Search, Stats) is built this way. Read `CLAUDE.md` (Architecture + Feature Map) first; do not re-derive the architecture from source.

## File layout

Create a new folder `Kami Sam Watches/<FeatureName>/` containing:

1. `<FeatureName>View.swift` — SwiftUI view wrapped in its own `NavigationStack`, owning its ViewModel via `@State private var viewModel`, initialized in `init(dataStore: DataStore)` with `_viewModel = State(initialValue: ...)`. Load data with `.task { await viewModel.load() }`. Handle the four states: loading (`ProgressView`), error (`ContentUnavailableView`), empty (`ContentUnavailableView`), and content (`List` with `.listStyle(.plain)`). Put rows in `private struct` subviews in the same file.
2. `<FeatureName>ViewModel.swift` — `@Observable final class` (no `@MainActor` annotation needed — the project defaults to MainActor isolation). Expose `isLoading`, `errorMessage: String?`, and the data array. Take dependencies in `init` with the live service as a default argument: `init(service: any FooService = LiveFooService(), dataStore: DataStore)`.

The project uses Xcode synchronized folders — new files under `Kami Sam Watches/` are auto-included in the target. **Do not touch `project.pbxproj`.**

## If the feature needs new remote data

- Add methods to the `TMDBService` protocol + `LiveTMDBService` (in `Services/TMDBService.swift`) for raw endpoints; response structs are `Decodable, Sendable` with snake_case property names matching the TMDB JSON.
- For per-show fan-out or business logic, create a new protocol + `Live*` struct in `Services/` (model on `EpisodeService`/`UpcomingReleaseService`: `withThrowingTaskGroup` for parallelism, composing `any TMDBService`).
- Domain models used by views are value types in `Models/` (`Identifiable, Sendable`).

## If the feature needs new persisted data

Add/extend a SwiftData `@Model` in `Models/`, register it in the `.modelContainer(for:)` list in `Kami_Sam_WatchesApp.swift`, and route **all** reads/writes through `DataStore` (add methods there; call `save()` + `refresh()` after mutations).

## Wire-up

Add a `Tab("Name", systemImage: "sf.symbol") { FeatureView(dataStore: dataStore) }` entry in `ContentView.swift` (only needed for new top-level tabs; detail screens use `NavigationLink`/`navigationDestination`).

## Finish

1. Add XCTest unit tests in `Kami Sam WatchesTests/` for any new service/ViewModel logic, injecting `MockTMDBService` (extend it if needed rather than writing a new mock). Remember `@testable import Kami_Sam_Watches` and that `DataStore` seeds 5 default shows into an empty store.
2. Build and test with the `xcodebuild` commands in `CLAUDE.md` (needs the `DEVELOPER_DIR` prefix).
3. Verify the code follows `AGENTS.md` (or run the `swift-reviewer` agent on the diff).
4. **Update the Feature Map in `CLAUDE.md`** with the new feature.
