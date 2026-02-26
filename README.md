# Gato: Cat Breeds iOS App

`Gato` is a SwiftUI iOS app built with The Composable Architecture (TCA). It loads breeds from [The Cat API](https://thecatapi.com/), supports search and favorites, and keeps working with cached data offline.

## Stack

- `SwiftUI`
- `ComposableArchitecture` (`@Reducer`, `StoreOf`, `TestStore`)
- `Core Data` persistence
- `URLSession` API/image networking
- `OSLog` categories: `api`, `persistence`, `ui`
- `Swift Testing` + `TestStore` for unit/integration tests
- `XCUITest` (`XCTest`) for UI automation

## Toolchain and Dependency Versions

- `Xcode 26.2` (`17C52`)
- `swift-composable-architecture 1.24.0` (TCA)
- `swift-navigation 2.7.0` (used with TCA-driven navigation)

Source of truth for dependency pins: `gato.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Current Architecture

### Features

- `AppFeature`
  - Tab selection state
  - Cross-tab synchronization hooks
- `BreedsFeature`
  - Cached + remote sync
  - Debounced local search
  - Local pagination
  - Favorite toggling
  - Breed image hydration
- `FavoritesFeature`
  - Favorite-only listing
  - Favorite removal
  - Average lifespan from `lifeSpan.max`
- `BreedDetailFeature`
  - Detail presentation state
- `BreedDetailView`
  - Two modes:
  - Live mode (syncs with `BreedsFeature` store by `breedID`)
  - Standalone mode (state + callback)

### Core

- `Core/APIClient/CatAPIClient.swift`
  - Breeds + breed image endpoints
  - API error mapping
  - Mismatched image-response guard by breed id
- `Core/Persistence/PersistenceClient.swift`
  - Core Data-backed breed/favorite persistence
- `Core/ImageClient/ImageLoadService.swift`
  - Actor-based image loading
  - In-memory image cache
  - Request deduplication
  - Subscriber tracking and cancellation
- `Core/DesignSystem/RemoteImageView.swift`
  - Cell-safe async image rendering
  - `activeURL` guard to prevent wrong-image reuse

## Offline and Sync Strategy

Read flow:
1. Load cached breeds.
2. Merge persisted favorites.
3. Render immediately.
4. Attempt remote refresh.

Write flow:
1. Persist favorite toggle first.
2. Reflect result in reducer state.
3. Sync favorite state across tabs/views.

Behavior:
- Offline + cache available: show cached data with offline banner.
- Offline + no cache: show fatal offline empty state.

## Pagination Strategy

Breeds are fully synced from API and paginated locally (`pageSize`, `currentPage`, `canLoadMore`).

Reason:
- More deterministic than relying on remote pagination metadata.
- Better offline behavior.

## API Key Setup

All `*.xcconfig*` files are intentionally ignored and not tracked.

Create local files:
1. `Config/Secrets.xcconfig`
2. `Config/Debug.xcconfig`
3. `Config/Release.xcconfig`

Recommended contents:

```xcconfig
// Config/Secrets.xcconfig
CAT_API_KEY = YOUR_CAT_API_KEY_HERE
```

```xcconfig
// Config/Debug.xcconfig
#include "Secrets.xcconfig"
```

```xcconfig
// Config/Release.xcconfig
#include "Secrets.xcconfig"
```

The app reads `CAT_API_KEY` from:
1. `CAT_API_KEY` environment variable
2. `Info.plist` key `CAT_API_KEY` (fed from xcconfig)

## Testing

### Unit tests (`gatoTests`)
- Breeds reducer behavior (search/pagination/favorites/image hydration)
- Favorites reducer behavior
- Lifespan parsing
- API client response handling
- `ImageLoadService` concurrency/cancellation/cache behavior

### Integration tests (`gatoTests`)
- Core Data persistence CRUD
- Online sync then offline reload

### UI tests (`gatoUITests`)
- Launch + breeds list
- Search filtering
- Favorite flow and favorites tab
- Offline cached browsing
- Regression: detail favorite state refreshes after favorite removal in Favorites tab

## Important Regressions Prevented

- Favorite removal must update breed detail state when switching tabs.
- Favorites remove action must be outside the row `NavigationLink` hit area.
- Image assignment must be URL-safe for reused cells (`activeURL` check).

## Tradeoffs

- Uses Core Data instead of SwiftData in this environment.
- Local pagination favors determinism/offline over remote paging fidelity.

## Future Improvements

1. Add snapshot tests for key UI states.
2. Add pull-to-refresh/background refresh.
3. Split features/core into local Swift packages.
