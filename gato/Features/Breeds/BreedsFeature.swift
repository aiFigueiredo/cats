import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct BreedsFeature {
    @ObservableState
    struct State: Equatable {
        var breedsByID: [Breed.ID: Breed] = [:]
        var orderedBreedIDs: [Breed.ID] = []
        var filteredBreedIDs: [Breed.ID] = []
        var visibleCount = 0

        var isLoading = false
        var errorMessage: String?
        var bannerMessage: String?
        var isOfflineMode = false
        var showFatalOfflineState = false
        var hasLoaded = false

        var pageSize = 20
        var canLoadMore = false

        var searchQuery = ""

        var favoriteToggleInFlight: Set<String> = []
        var imageHydrationInFlight: Set<String> = []
        var pendingImageHydrationIDs: [String] = []
        var maxConcurrentHydrations = 4

        var visibleBreedIDs: [Breed.ID] {
            Array(filteredBreedIDs.prefix(visibleCount))
        }

        var visibleBreeds: [Breed] {
            visibleBreedIDs.compactMap { breedsByID[$0] }
        }
    }

    enum Action: Equatable {
        case onAppear
        case retryTapped
        case dismissBanner
        case toggleFavoriteTapped(String)
        case breedRowAppeared(String)
        case prefetchRequested([String])
        case favoriteFlagsRefreshed(Set<String>)
        case breedImageHydrated(String, URL?)

        case searchQueryChanged(String)
        case applySearchDebounced

        case cachedBreedsLoaded([Breed])
        case networkBreedsLoaded([Breed])
        case networkFailed(String, Bool)

        case favoritePersisted(String, Bool)
        case favoritePersistFailed(String, String)

        case loadNextPage
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.persistenceClient) var persistenceClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasLoaded else {
                    return refreshFavoriteFlagsEffect()
                }
                state.hasLoaded = true
                state.isLoading = true
                state.errorMessage = nil
                state.showFatalOfflineState = false
                return loadBreedsEffect()
                    .cancellable(id: "breeds-load", cancelInFlight: true)

            case .retryTapped:
                state.isLoading = true
                state.errorMessage = nil
                state.showFatalOfflineState = false
                return loadBreedsEffect()
                    .cancellable(id: "breeds-load", cancelInFlight: true)

            case .dismissBanner:
                state.bannerMessage = nil
                return .none

            case .toggleFavoriteTapped(let breedID):
                guard !state.favoriteToggleInFlight.contains(breedID) else { return .none }
                guard let existing = state.breedsByID[breedID] else { return .none }

                state.favoriteToggleInFlight.insert(breedID)
                let nextValue = !existing.isFavorite
                let persistenceClient = self.persistenceClient

                return .run { send in
                    do {
                        try persistenceClient.setFavorite(breedID, nextValue)
                        await send(.favoritePersisted(breedID, nextValue))
                    } catch {
                        let message = (error as? LocalizedError)?.errorDescription ?? "Failed to update favorite."
                        await send(.favoritePersistFailed(breedID, message))
                    }
                }

            case .favoritePersisted(let breedID, let isFavorite):
                state.favoriteToggleInFlight.remove(breedID)
                setFavorite(state: &state, breedID: breedID, isFavorite: isFavorite)
                return .none

            case .favoritePersistFailed(let breedID, let message):
                state.favoriteToggleInFlight.remove(breedID)
                state.bannerMessage = message
                return .none

            case .breedRowAppeared(let breedID):
                var effects: [Effect<Action>] = []

                if state.canLoadMore, let index = state.visibleBreedIDs.firstIndex(of: breedID) {
                    let thresholdIndex = max(state.visibleBreedIDs.count - 5, 0)
                    if index >= thresholdIndex {
                        effects.append(.send(.loadNextPage))
                    }
                }

                enqueueImageHydration(state: &state, breedID: breedID)
                effects.append(contentsOf: drainHydrationQueue(state: &state))

                return .merge(effects)

            case .prefetchRequested(let breedIDs):
                for breedID in breedIDs {
                    enqueueImageHydration(state: &state, breedID: breedID)
                }
                return .merge(drainHydrationQueue(state: &state))

            case .favoriteFlagsRefreshed(let favoriteIDs):
                setFavoriteFlags(state: &state, favoriteIDs: favoriteIDs)
                return .none

            case .breedImageHydrated(let breedID, let imageURL):
                state.imageHydrationInFlight.remove(breedID)
                if let imageURL {
                    setBreedImage(state: &state, breedID: breedID, imageURL: imageURL)
                }
                return .merge(drainHydrationQueue(state: &state))

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .run { send in
                    try await self.clock.sleep(for: .milliseconds(300))
                    await send(.applySearchDebounced)
                }
                .cancellable(id: "breeds-search-debounce", cancelInFlight: true)

            case .applySearchDebounced:
                recomputeFilter(state: &state, resetPagination: true)
                for breedID in state.visibleBreedIDs.prefix(12) {
                    enqueueImageHydration(state: &state, breedID: breedID)
                }
                return .merge(drainHydrationQueue(state: &state))

            case .cachedBreedsLoaded(let breeds):
                applyLoadedBreeds(state: &state, breeds: breeds)
                for breedID in state.visibleBreedIDs.prefix(12) {
                    enqueueImageHydration(state: &state, breedID: breedID)
                }
                return .merge(drainHydrationQueue(state: &state))

            case .networkBreedsLoaded(let breeds):
                state.isLoading = false
                state.isOfflineMode = false
                state.showFatalOfflineState = false
                applyLoadedBreeds(state: &state, breeds: breeds)
                for breedID in state.visibleBreedIDs.prefix(12) {
                    enqueueImageHydration(state: &state, breedID: breedID)
                }
                return .merge(drainHydrationQueue(state: &state))

            case .networkFailed(let message, let isOffline):
                state.isLoading = false
                if state.visibleBreedIDs.isEmpty {
                    state.errorMessage = message
                    state.showFatalOfflineState = isOffline
                } else {
                    state.bannerMessage = isOffline ? "Offline mode: showing cached data." : message
                    state.isOfflineMode = isOffline
                }
                AppLogger.ui.error("Breeds sync failed: \(message, privacy: .public)")
                return .none

            case .loadNextPage:
                appendNextPage(state: &state)
                for breedID in state.visibleBreedIDs.suffix(state.pageSize) {
                    enqueueImageHydration(state: &state, breedID: breedID)
                }
                return .merge(drainHydrationQueue(state: &state))
            }
        }
    }

    private func loadBreedsEffect() -> Effect<Action> {
        let loadBreeds = self.persistenceClient.loadBreeds
        let upsertBreeds = self.persistenceClient.upsertBreeds
        let fetchBreeds = self.apiClient.fetchBreeds

        return .run { send in
            do {
                let cached = try loadBreeds()
                if !cached.isEmpty {
                    await send(.cachedBreedsLoaded(cached))
                }
            } catch {
                // Ignore cache errors and continue with network.
            }

            do {
                let remote = try await fetchAllBreeds(fetchBreeds: fetchBreeds)
                try upsertBreeds(remote, Date())
                let merged = try loadBreeds()
                await send(.networkBreedsLoaded(merged))
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Failed to refresh breeds."
                let isOffline = (error as? CatAPIError) == .offline
                await send(.networkFailed(message, isOffline))
            }
        }
    }

    private func refreshFavoriteFlagsEffect() -> Effect<Action> {
        let loadFavoriteIDs = self.persistenceClient.loadFavoriteIDs

        return .run { send in
            do {
                let favoriteIDs = try loadFavoriteIDs()
                await send(.favoriteFlagsRefreshed(favoriteIDs))
            } catch {
                // No-op: favorite flags can be refreshed on next lifecycle event.
            }
        }
    }

    private func hydrateBreedImageEffect(breedID: String) -> Effect<Action> {
        let fetchBreedImage = self.apiClient.fetchBreedImage
        let updateBreedImage = self.persistenceClient.updateBreedImage

        return .run { send in
            do {
                let imageURL = try await fetchBreedImage(breedID)
                if let imageURL {
                    try? updateBreedImage(breedID, imageURL)
                }
                await send(.breedImageHydrated(breedID, imageURL))
            } catch {
                await send(.breedImageHydrated(breedID, nil))
            }
        }
    }

    private func applyLoadedBreeds(state: inout State, breeds: [Breed]) {
        let sorted = breeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        state.orderedBreedIDs = sorted.map(\.id)
        state.breedsByID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        state.pendingImageHydrationIDs.removeAll()
        state.imageHydrationInFlight = state.imageHydrationInFlight.intersection(Set(state.orderedBreedIDs))
        recomputeFilter(state: &state, resetPagination: true)
    }

    private func setFavorite(state: inout State, breedID: String, isFavorite: Bool) {
        guard var breed = state.breedsByID[breedID] else { return }
        if breed.isFavorite != isFavorite {
            breed.isFavorite = isFavorite
            state.breedsByID[breedID] = breed
            recomputeFilter(state: &state, resetPagination: false)
        }
    }

    private func setBreedImage(state: inout State, breedID: String, imageURL: URL) {
        guard var breed = state.breedsByID[breedID] else { return }
        if breed.imageURL != imageURL {
            breed.imageURL = imageURL
            state.breedsByID[breedID] = breed
            recomputeFilter(state: &state, resetPagination: false)
        }
    }

    private func setFavoriteFlags(state: inout State, favoriteIDs: Set<String>) {
        var didChange = false
        for id in state.orderedBreedIDs {
            guard var breed = state.breedsByID[id] else { continue }
            let shouldBeFavorite = favoriteIDs.contains(id)
            if breed.isFavorite != shouldBeFavorite {
                breed.isFavorite = shouldBeFavorite
                state.breedsByID[id] = breed
                didChange = true
            }
        }
        if didChange {
            recomputeFilter(state: &state, resetPagination: false)
        }
    }

    private func recomputeFilter(state: inout State, resetPagination: Bool) {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            state.filteredBreedIDs = state.orderedBreedIDs
        } else {
            state.filteredBreedIDs = state.orderedBreedIDs.filter { id in
                guard let breed = state.breedsByID[id] else { return false }
                return breed.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        if resetPagination {
            state.visibleCount = 0
            appendNextPage(state: &state)
        } else {
            state.visibleCount = min(state.visibleCount, state.filteredBreedIDs.count)
            state.canLoadMore = state.visibleCount < state.filteredBreedIDs.count
        }
    }

    private func appendNextPage(state: inout State) {
        guard !state.filteredBreedIDs.isEmpty else {
            state.visibleCount = 0
            state.canLoadMore = false
            return
        }

        let nextCount = min(state.visibleCount + state.pageSize, state.filteredBreedIDs.count)
        guard nextCount > state.visibleCount else {
            state.canLoadMore = false
            return
        }

        state.visibleCount = nextCount
        state.canLoadMore = state.visibleCount < state.filteredBreedIDs.count
    }

    private func enqueueImageHydration(state: inout State, breedID: String) {
        guard let breed = state.breedsByID[breedID] else { return }
        guard breed.imageURL == nil else { return }
        guard !state.imageHydrationInFlight.contains(breedID) else { return }
        guard !state.pendingImageHydrationIDs.contains(breedID) else { return }
        state.pendingImageHydrationIDs.append(breedID)
    }

    private func drainHydrationQueue(state: inout State) -> [Effect<Action>] {
        var effects: [Effect<Action>] = []

        while state.imageHydrationInFlight.count < state.maxConcurrentHydrations,
              let nextBreedID = state.pendingImageHydrationIDs.first {
            state.pendingImageHydrationIDs.removeFirst()
            state.imageHydrationInFlight.insert(nextBreedID)
            effects.append(hydrateBreedImageEffect(breedID: nextBreedID))
        }

        return effects
    }

    private func fetchAllBreeds(
        fetchBreeds: @escaping (_ page: Int, _ limit: Int) async throws -> [Breed]
    ) async throws -> [Breed] {
        let perPage = 50
        var page = 0
        var allBreeds: [Breed] = []

        while true {
            let chunk = try await fetchBreeds(page, perPage)
            if chunk.isEmpty {
                break
            }
            allBreeds.append(contentsOf: chunk)
            if chunk.count < perPage {
                break
            }
            page += 1
            if page > 20 {
                break
            }
        }

        return allBreeds
    }
}
