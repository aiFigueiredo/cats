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
        var visibleBreedIDs: [Breed.ID] = []
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
        var pendingImageHydrationOrder: [Breed.ID] = []
        var pendingImageHydrationSet: Set<Breed.ID> = []
        var pendingImageHydrationHead = 0
        var maxConcurrentHydrations = 4
        var pendingImagePersistence: [Breed.ID: URL] = [:]
        var preparationGeneration = 0
        var pendingPreparedBreedsCount = 0

        var visibleBreeds: [Breed] {
            visibleBreedIDs.compactMap { breedsByID[$0] }
        }
    }

    struct PreparedBreedsViewState: Equatable, Sendable {
        var breedsByID: [Breed.ID: Breed]
        var orderedBreedIDs: [Breed.ID]
        var filteredBreedIDs: [Breed.ID]
        var visibleBreedIDs: [Breed.ID]
        var visibleCount: Int
        var canLoadMore: Bool
    }

    enum Action: Equatable {
        case onAppear
        case retryTapped
        case dismissBanner
        case toggleFavoriteTapped(String)
        case flushPendingImagePersistence
        case favoriteFlagsRefreshed(Set<String>)
        case breedImageHydrated(String, URL?)

        case searchQueryChanged(String)
        case applySearchDebounced

        case cachedBreedsLoaded([Breed])
        case networkBreedsLoaded([Breed])
        case preparedBreedsViewState(PreparedBreedsViewState, Int)
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
                let setFavorite = self.persistenceClient.setFavorite

                return .run { send in
                    do {
                        try setFavorite(breedID, nextValue)
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

            case .flushPendingImagePersistence:
                let cancelScheduledFlush = Effect<Action>.cancel(id: "image-persistence-flush")
                guard !state.pendingImagePersistence.isEmpty else { return .none }
                let updates = state.pendingImagePersistence
                state.pendingImagePersistence.removeAll(keepingCapacity: true)
                let updateBreedImagesBatch = self.persistenceClient.updateBreedImagesBatch

                return .merge(
                    cancelScheduledFlush,
                    .run { _ in
                        try? updateBreedImagesBatch(updates, Date())
                    }
                )

            case .favoriteFlagsRefreshed(let favoriteIDs):
                setFavoriteFlags(state: &state, favoriteIDs: favoriteIDs)
                return .none

            case .breedImageHydrated(let breedID, let imageURL):
                var effects: [Effect<Action>] = []
                state.imageHydrationInFlight.remove(breedID)
                if let imageURL {
                    if setBreedImage(state: &state, breedID: breedID, imageURL: imageURL) {
                        state.pendingImagePersistence[breedID] = imageURL
                        effects.append(scheduleImagePersistenceFlushEffect())
                    }
                }
                effects.append(contentsOf: drainHydrationQueue(state: &state))
                return .merge(effects)

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .run { send in
                    try await self.clock.sleep(for: .milliseconds(300))
                    await send(.applySearchDebounced)
                }
                .cancellable(id: "breeds-search-debounce", cancelInFlight: true)

            case .applySearchDebounced:
                let breeds = state.orderedBreedIDs.compactMap { state.breedsByID[$0] }
                return scheduleBreedsPreparation(state: &state, breeds: breeds)

            case .cachedBreedsLoaded(let breeds):
                return scheduleBreedsPreparation(state: &state, breeds: breeds)

            case .networkBreedsLoaded(let breeds):
                state.isLoading = false
                state.isOfflineMode = false
                state.showFatalOfflineState = false
                return scheduleBreedsPreparation(state: &state, breeds: breeds)

            case let .preparedBreedsViewState(prepared, generation):
                guard generation == state.preparationGeneration else { return .none }
                state.breedsByID = prepared.breedsByID
                state.orderedBreedIDs = prepared.orderedBreedIDs
                state.filteredBreedIDs = prepared.filteredBreedIDs
                state.visibleBreedIDs = prepared.visibleBreedIDs
                state.visibleCount = prepared.visibleCount
                state.canLoadMore = prepared.canLoadMore
                state.pendingPreparedBreedsCount = 0
                resetHydrationQueue(state: &state)
                state.pendingImagePersistence.removeAll(keepingCapacity: true)
                state.imageHydrationInFlight = state.imageHydrationInFlight.intersection(Set(state.orderedBreedIDs))
                enqueueVisibleImageHydration(state: &state)
                return .merge(drainHydrationQueue(state: &state))

            case .networkFailed(let message, let isOffline):
                state.isLoading = false
                if state.visibleBreedIDs.isEmpty, state.pendingPreparedBreedsCount == 0 {
                    state.errorMessage = message
                    state.showFatalOfflineState = isOffline
                } else {
                    state.errorMessage = nil
                    state.showFatalOfflineState = false
                    state.bannerMessage = isOffline ? "Offline mode: showing cached data." : message
                    state.isOfflineMode = isOffline
                }
                AppLogger.ui.error("Breeds sync failed: \(message, privacy: .public)")
                return .none

            case .loadNextPage:
                let previousVisibleCount = state.visibleCount
                appendNextPage(state: &state)
                if state.visibleCount > previousVisibleCount {
                    let newRange = previousVisibleCount ..< state.visibleCount
                    for breedID in state.visibleBreedIDs[newRange] {
                        enqueueImageHydration(state: &state, breedID: breedID)
                    }
                }
                return .merge(drainHydrationQueue(state: &state))
            }
        }
    }

    private func scheduleImagePersistenceFlushEffect() -> Effect<Action> {
        .run { send in
            try await self.clock.sleep(for: .milliseconds(250))
            await send(.flushPendingImagePersistence)
        }
        .cancellable(id: "image-persistence-flush", cancelInFlight: true)
    }

    private func scheduleBreedsPreparation(state: inout State, breeds: [Breed]) -> Effect<Action> {
        state.preparationGeneration &+= 1
        state.pendingPreparedBreedsCount = breeds.count
        let generation = state.preparationGeneration
        let query = state.searchQuery
        let pageSize = state.pageSize

        return .run { send in
            let prepared = await Task.detached(priority: .userInitiated) {
                Self.prepareBreedsViewState(
                    breeds: breeds,
                    searchQuery: query,
                    pageSize: pageSize
                )
            }.value
            await send(.preparedBreedsViewState(prepared, generation))
        }
        .cancellable(id: "breeds-prepare", cancelInFlight: true)
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

        return .run { send in
            do {
                let imageURL = try await fetchBreedImage(breedID)
                await send(.breedImageHydrated(breedID, imageURL))
            } catch {
                await send(.breedImageHydrated(breedID, nil))
            }
        }
    }

    private func setFavorite(state: inout State, breedID: String, isFavorite: Bool) {
        guard var breed = state.breedsByID[breedID] else { return }
        if breed.isFavorite != isFavorite {
            breed.isFavorite = isFavorite
            state.breedsByID[breedID] = breed
        }
    }

    @discardableResult
    private func setBreedImage(state: inout State, breedID: String, imageURL: URL) -> Bool {
        guard var breed = state.breedsByID[breedID] else { return false }
        guard breed.imageURL != imageURL else { return false }
        breed.imageURL = imageURL
        state.breedsByID[breedID] = breed
        return true
    }

    private func setFavoriteFlags(state: inout State, favoriteIDs: Set<String>) {
        for id in state.orderedBreedIDs {
            guard var breed = state.breedsByID[id] else { continue }
            let shouldBeFavorite = favoriteIDs.contains(id)
            if breed.isFavorite != shouldBeFavorite {
                breed.isFavorite = shouldBeFavorite
                state.breedsByID[id] = breed
            }
        }
    }

    private func appendNextPage(state: inout State) {
        guard !state.filteredBreedIDs.isEmpty else {
            state.visibleCount = 0
            state.canLoadMore = false
            refreshVisibleWindow(state: &state)
            return
        }

        let nextCount = min(state.visibleCount + state.pageSize, state.filteredBreedIDs.count)
        guard nextCount > state.visibleCount else {
            state.canLoadMore = false
            refreshVisibleWindow(state: &state)
            return
        }

        state.visibleCount = nextCount
        state.canLoadMore = state.visibleCount < state.filteredBreedIDs.count
        refreshVisibleWindow(state: &state)
    }

    private func refreshVisibleWindow(state: inout State) {
        state.visibleBreedIDs = Array(state.filteredBreedIDs.prefix(state.visibleCount))
    }

    private func enqueueVisibleImageHydration(state: inout State) {
        for breedID in state.visibleBreedIDs {
            enqueueImageHydration(state: &state, breedID: breedID)
        }
    }

    private func enqueueImageHydration(state: inout State, breedID: String) {
        guard let breed = state.breedsByID[breedID] else { return }
        guard breed.imageURL == nil else { return }
        guard !state.imageHydrationInFlight.contains(breedID) else { return }
        guard state.pendingImageHydrationSet.insert(breedID).inserted else { return }
        state.pendingImageHydrationOrder.append(breedID)
    }

    private func drainHydrationQueue(state: inout State) -> [Effect<Action>] {
        var effects: [Effect<Action>] = []

        while state.imageHydrationInFlight.count < state.maxConcurrentHydrations,
              let nextBreedID = dequeueImageHydration(state: &state) {
            state.imageHydrationInFlight.insert(nextBreedID)
            effects.append(hydrateBreedImageEffect(breedID: nextBreedID))
        }

        return effects
    }

    private func dequeueImageHydration(state: inout State) -> Breed.ID? {
        guard state.pendingImageHydrationHead < state.pendingImageHydrationOrder.count else {
            return nil
        }

        let breedID = state.pendingImageHydrationOrder[state.pendingImageHydrationHead]
        state.pendingImageHydrationHead += 1
        state.pendingImageHydrationSet.remove(breedID)
        compactHydrationQueueIfNeeded(state: &state)
        return breedID
    }

    private func compactHydrationQueueIfNeeded(state: inout State) {
        if state.pendingImageHydrationHead == state.pendingImageHydrationOrder.count {
            resetHydrationQueue(state: &state)
            return
        }

        if state.pendingImageHydrationHead > 64,
           state.pendingImageHydrationHead * 2 > state.pendingImageHydrationOrder.count {
            state.pendingImageHydrationOrder.removeFirst(state.pendingImageHydrationHead)
            state.pendingImageHydrationHead = 0
        }
    }

    private func resetHydrationQueue(state: inout State) {
        state.pendingImageHydrationOrder.removeAll(keepingCapacity: true)
        state.pendingImageHydrationSet.removeAll(keepingCapacity: true)
        state.pendingImageHydrationHead = 0
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

    nonisolated private static func prepareBreedsViewState(
        breeds: [Breed],
        searchQuery: String,
        pageSize: Int
    ) -> PreparedBreedsViewState {
        let sorted = breeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let orderedBreedIDs = sorted.map(\.id)
        let breedsByID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredBreedIDs: [Breed.ID]
        if query.isEmpty {
            filteredBreedIDs = orderedBreedIDs
        } else {
            filteredBreedIDs = orderedBreedIDs.filter { id in
                guard let breed = breedsByID[id] else { return false }
                return breed.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        let visibleCount = min(pageSize, filteredBreedIDs.count)
        let visibleBreedIDs = Array(filteredBreedIDs.prefix(visibleCount))

        return PreparedBreedsViewState(
            breedsByID: breedsByID,
            orderedBreedIDs: orderedBreedIDs,
            filteredBreedIDs: filteredBreedIDs,
            visibleBreedIDs: visibleBreedIDs,
            visibleCount: visibleCount,
            canLoadMore: visibleCount < filteredBreedIDs.count
        )
    }
}
