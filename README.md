# Kami Sam Watches

A personal TV-show tracker for iPhone and iPad, built with SwiftUI.

## What it does

- **Watch Next** — shows the next unwatched episode for each show you follow, with badges for premieres, latest episodes, and new releases
- **Upcoming** — lists future air dates for your tracked shows, sorted by date
- **Search** — find any TV show via TMDB and add it to your list; drill into seasons and episodes to mark things watched
- **Stats** — watch time, episode counts, and full history; import your watch history from a TV Time export ZIP

## Requirements

- iOS 26.5+
- Xcode 16+ (located at `~/Downloads/Xcode.app`)
- A [TMDB](https://www.themoviedb.org/) API read token

## Setup

1. Clone the repo
2. Create `Kami Sam Watches/Secrets.swift` (gitignored) with your TMDB bearer token:
   ```swift
   enum Secrets {
       static let tmdbBearerToken = "your_token_here"
   }
   ```
3. Open `Kami Sam Watches.xcodeproj` in Xcode and run on a simulator or device

## Tech

- SwiftUI + SwiftData
- MVVM architecture with service protocols
- TMDB REST API for show/episode metadata
- ZIPFoundation for TV Time import
