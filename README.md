# Gato: Cat Breeds iOS App

`Gato` is a SwiftUI iOS app that uses a TCA-style architecture to browse cat breeds from [The Cat API](https://thecatapi.com/), search locally, favorite breeds, and keep working with cached data when offline.

## Stack

- `SwiftUI` for UI
- Feature-first, reducer/store architecture (TCA-inspired)
- `Core Data` persistence (used instead of SwiftData due current build-environment macro limitations)
- `URLSession` + typed API client for The Cat API
- `XCTest` + `XCUITest` test suites
- `OSLog` structured logging (`api`, `persistence`, `ui`)

## Architecture

### Features

- `AppFeature`
  - Root tab navigation
- `BreedsFeature`
  - Breeds list
  - Debounced search
  - Local pagination state
  - Favorite toggling
  - Offline/error states
- `FavoritesFeature`
  - Favorite-only list
  - Average lifespan calculation from `lifeSpan.max`
- `BreedDetailFeature`
  - Breed detail presentation model and detail screen

### Core

- `Core/Models`
  - `Breed`, `LifeSpanRange`
- `Core/APIClient`
  - `CatAPIClient`, request/response mapping, error normalization
- `Core/Persistence`
  - `PersistenceClient`, in-memory and on-disk Core Data stores
- `Core/ImageClient`
  - URL-request policy for image caching
- `Core/Logging`
  - `OSLog` categories

## Offline-First Strategy

Read flow:
1. Load cached breeds from persistence.
2. Merge persisted favorites.
3. Render cached data immediately when present.
4. Attempt network sync.

Write flow:
1. Favorite toggles persist first (`PersistenceClient.setFavorite`).
2. UI updates after persistence confirms success.

If network is offline and cache exists, the app shows an offline banner and continues using cached data.
If network is offline and cache is empty, the app shows a dedicated offline-empty screen with retry.

## Pagination Strategy

The app fetches all remote breeds during sync and applies pagination locally (`pageSize`, `currentPage`, `canLoadMore`) as the user scrolls.

Why:
- The Cat API pagination metadata can be inconsistent across environments.
- Local pagination gives deterministic behavior and strong offline support.

## API Key Configuration

Do not commit secrets.

Files provided:
- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`
- `Config/Secrets.xcconfig.example`

Setup:
1. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`.
2. Set `THE_CAT_API_KEY`.
3. Ensure build config includes `CAT_API_KEY` (currently read from `Info.plist` key `CAT_API_KEY` or `CAT_API_KEY` environment variable).

In CI, set `CAT_API_KEY` as a secret environment variable.

## Testing Strategy

### Unit tests (`gatoTests`)
- Reducer behavior (pagination/search/favorite flow)
- Lifespan parsing
- Favorites average lifespan logic

### Integration tests (`gatoTests`)
- Real in-memory persistence + mocked API
- Sync then offline reload behavior
- Favorite persistence CRUD

### End-to-end UI tests (`gatoUITests`)
- App launch and breeds list
- Search flow
- Favorite/unfavorite flow
- Favorites average lifespan presence
- Offline cached browsing

## Known Tradeoffs

- Uses a lightweight reducer/store implementation instead of importing Point-Free TCA package directly.
- Core Data used instead of SwiftData because SwiftData macro expansion is not available in this environment.
- Local pagination after full sync favors deterministic UX and offline support over strict remote paging.

## Future Improvements

1. Move to upstream Composable Architecture package when environment supports dependency integration.
2. Add remote image endpoint enrichment for breeds without image URLs.
3. Add snapshot tests for key states.
4. Add pull-to-refresh and background sync scheduling.
5. Split features/core into local Swift packages once package linking is enabled.
