# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read this file instead of re-analyzing the codebase.** The Architecture and Feature Map sections below are the source of truth for how the app is put together. If you add, remove, or significantly change a feature, update this file in the same change.

Swift/SwiftUI coding rules live in [AGENTS.md](AGENTS.md) — follow them for all code you write. The `swift-reviewer` agent (`.claude/agents/swift-reviewer.md`) reviews diffs against those rules. To add a new feature/tab, use the `add-feature` skill (`.claude/skills/add-feature/SKILL.md`).

## Project Overview

**Kami Sam Watches** is a personal TV-show tracker for iPhone/iPad (iOS 26.5+, bundle ID `slic.Kami-Sam-Watches`). It tracks which shows you follow, which episode to watch next, upcoming air dates, and watch statistics. All show/episode metadata comes from the TMDB API; watch history can be imported from a TV Time export ZIP.

Key Swift settings in effect project-wide:
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor` unless explicitly annotated otherwise (so `@Observable` classes and views need no annotation; opt out with `nonisolated`)
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Swift 6 concurrency model is active
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`

## Build & Run

Xcode is installed at `~/Downloads/Xcode.app`. Prefix all `xcodebuild` calls with `DEVELOPER_DIR`:

```bash
# Build for simulator
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcodebuild \
  -project "Kami Sam Watches.xcodeproj" \
  -scheme "Kami Sam Watches" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  build

# Run all tests
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcodebuild \
  -project "Kami Sam Watches.xcodeproj" \
  -scheme "Kami Sam Watches" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  test

# Run a single test class
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcodebuild \
  -project "Kami Sam Watches.xcodeproj" \
  -scheme "Kami Sam Watches" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:"Kami Sam WatchesTests/SomeTestClass" \
  test
```

Opening in Xcode: `open -a "$HOME/Downloads/Xcode.app" "Kami Sam Watches.xcodeproj"`

### Xcode project facts

- Both targets use **`PBXFileSystemSynchronizedRootGroup`** (Xcode 16-style synchronized folders). New `.swift` files dropped into `Kami Sam Watches/` or `Kami Sam WatchesTests/` are picked up automatically — **never edit `project.pbxproj` to add source files**.
- One SPM dependency: **ZIPFoundation** (used only by `TVTimeImporter`). Do not add third-party frameworks without asking first.
- **`Kami Sam Watches/Secrets.swift` is gitignored and required to build.** It defines `enum Secrets { static let tmdbBearerToken = "..." }` (a TMDB API read token). If it's missing on a fresh clone, ask the user for the token and recreate the file; never commit it.
- App module name for tests: `@testable import Kami_Sam_Watches`. Test target: `Kami Sam WatchesTests` (XCTest, not Swift Testing).

## Architecture

MVVM + service protocols, all state flowing through one `@Observable` store:

```
SwiftData (@Model: TrackedShow, WatchEvent)
        │
    DataStore (@Observable, owns ModelContext, seeds 5 default shows on first run)
        │  created once in ContentView, passed by reference into each tab
        ▼
Feature ViewModels (@Observable) ──▶ Service protocols ──▶ LiveTMDBService ──▶ TMDB REST API
        │                            (EpisodeService,
        ▼                             UpcomingReleaseService, TMDBService)
Feature Views (one folder per tab)
```

- **Persistence**: only two SwiftData models — `TrackedShow` (a followed show: `tmdbId`, `showName`, `addedAt`, `hiddenFromWatchNext`) and `WatchEvent` (one watched episode: show id, season, episode, duration, `watchedAt`). Everything else (episodes, seasons, upcoming releases) is fetched from TMDB on demand and held in value-type models (`Episode`, `UpcomingRelease` in `Models/`).
- **`DataStore`** (`Services/DataStore.swift`) is the single mutation point: add/remove/hide shows, mark/toggle watched, TV Time bulk import with dedup, stats aggregates, and `progressLookup` ([tmdbId: (season, episode)] of last-watched). It refetches both tables after every mutation (`refresh()`), so views observing it update automatically.
- **Services are protocols with `Live*` structs** defaulted in ViewModel initializers; tests inject `MockTMDBService`. `TMDBService` is the low-level REST client (show detail, season detail, search, TVDB-id lookup; bearer auth from `Secrets`). `EpisodeService` and `UpcomingReleaseService` compose it with `withThrowingTaskGroup` for parallel per-show fetches.
- **Entry**: `Kami_Sam_WatchesApp` sets up the model container → `ContentView` builds the `DataStore` and a dark-mode `TabView` with the four tabs.
- **Shared UI**: `ThumbnailImage`, `BadgeChip`, `Theme`, and `cardRow()` live in `Kami Sam Watches/Shared/`. `ThumbnailSize` controls aspect-ratio variants (`.still`, `.stillLarge`, `.poster`, `.posterLarge`). `TMDBFormat` (`Services/TMDBFormat.swift`) owns the shared TMDB date parser and image URL builder.
- **Image/date helpers**: `CachingTMDBService` and `TMDBCache` (`Services/`) wrap `LiveTMDBService` with a 30-minute in-memory cache; `TMDB.shared` is the singleton entry point used by all ViewModels.

## Feature Map

| Tab | Folder | What it does |
|---|---|---|
| **Watch Next** | `WatchNext/` | For each tracked (non-hidden) show, shows the next unwatched episode. `LiveEpisodeService.resolveNextEpisode` takes last progress, tries episode+1 in the same season, then falls to the next season's E1. Badges: `.premiere` (E1), `.latest` (matches `last_episode_to_air`), `.new` (aired ≤14 days ago). Filter chips All/New/Premieres are driven by `WatchNextFilter` (logic in `WatchNextViewModel.filteredEpisodes`). Row actions: Mark Watched, swipe-to-hide show. Season progress bar derived from `Episode.seasonProgress`. |
| **Upcoming** | `Upcoming/` | Future releases for all tracked shows, from TMDB `next_episode_to_air`, sorted by date. `ReleaseKind` distinguishes season premieres from regular episodes; rows show the show poster (`UpcomingRelease.posterURL`, from `poster_path` falling back to the season poster) next to a date block with day number + month abbreviation (`UpcomingRelease.releaseDayNumber`/`releaseMonthAbbrev`); relative date labels ("Today", "Tomorrow", "in N days"). |
| **Search** | `Search/` | TMDB TV search with 350 ms debounce (`SearchViewModel.search`). Portrait poster thumbnails (`.poster` size). Rows track/untrack shows; tapping opens `ShowDetailView` (backdrop hero header, poster, overview, season list with `ProgressView` per season via `DataStore.seasonProgress`) → `SeasonDetailView` (episode list with episode still thumbnails, overview, toggle-watched). `ShowDetailViewModel` is private inside `ShowDetailView.swift`. |
| **Stats** | `Stats/` | `StatsViewModel` (owned by `StatsView`) computes `watchTimeLabel` (mo/d/h/m) and `monthlyActivity` ([MonthlyActivity]) for a 12-month zero-filled bar chart. 2×2 metric tile grid + Swift Charts `BarMark` activity chart + watch-event history list. Toolbar menu hosts **Import from TV Time**: `.fileImporter` for a ZIP → `TVTimeImporter`. |

**TV Time import** (`Services/TVTimeImporter.swift`): unzips the export (ZIPFoundation), finds `tracking-prod-records-v2.csv`, parses it with the in-file RFC 4180 `CSVParser`, keeps `watch-episode`/`rewatch-episode` rows, resolves each TVDB show id to TMDB (`findShow(tvdbId:)`, falling back to name search), then bulk-inserts via `DataStore.importData` which skips episodes already recorded. Progress is reported through a `Phase` callback rendered as an overlay in Stats.

## Testing

Unit tests only (XCTest) in `Kami Sam WatchesTests/`:
- `MockTMDBService.swift` — configurable mock used by all service tests; extend it rather than creating new mocks.
- `DataStoreTests` use an in-memory `ModelContainer` (`ModelConfiguration(isStoredInMemoryOnly: true)`); note `DataStore.init` seeds 5 default shows when the store is empty — tests must account for that.
- Coverage exists for models, `EpisodeService` next-episode resolution, `UpcomingReleaseService`, `TVTimeImporter`/CSV parsing, `DataStore` mutations/import dedup/`seasonProgress`, `WatchNextViewModelTests` (filter logic), and `StatsViewModelTests` (monthly bucketing, `watchTimeLabel`).

New logic goes in ViewModels or Services so it is testable; add tests alongside in the same style.
