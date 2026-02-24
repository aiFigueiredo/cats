import Foundation
import OSLog

struct BreedsFeature {
    struct State {
        var allBreeds: [Breed] = []
        var filteredBreeds: [Breed] = []
        var breeds: [Breed] = []

        var isLoading = false
        var isLoadingPage = false
        var errorMessage: String?
        var bannerMessage: String?
        var isOfflineMode = false
        var showFatalOfflineState = false
        var hasLoaded = false

        var currentPage = 0
        var pageSize = 20
        var canLoadMore = false

        var searchQuery = ""
        var searchToken = UUID()

        var favoriteToggleInFlight: Set<String> = []
        var imageHydrationInFlight: Set<String> = []
    }

    enum Action {
        case onAppear
        case retryTapped
        case dismissBanner
        case toggleFavoriteTapped(String)
        case breedRowAppeared(String)
        case favoriteFlagsRefreshed(Set<String>)
        case breedImageHydrated(String, URL?)

        case searchQueryChanged(String)
        case applySearchDebounced(UUID)

        case cachedBreedsLoaded([Breed])
        case networkBreedsLoaded([Breed])
        case networkFailed(String, Bool)

        case favoritePersisted(String, Bool)
        case favoritePersistFailed(String, String)

        case loadNextPage
    }

    static func reduce(
        state: inout State,
        action: Action,
        dependencies: AppDependencies
    ) -> [Effect<Action>] {
        switch action {
        case .onAppear:
            guard !state.hasLoaded else {
                return [refreshFavoriteFlagsEffect(dependencies: dependencies)]
            }
            state.hasLoaded = true
            state.isLoading = true
            state.errorMessage = nil
            state.showFatalOfflineState = false
            return [loadBreedsEffect(dependencies: dependencies)]

        case .retryTapped:
            state.isLoading = true
            state.errorMessage = nil
            state.showFatalOfflineState = false
            return [loadBreedsEffect(dependencies: dependencies)]

        case .dismissBanner:
            state.bannerMessage = nil
            return []

        case .toggleFavoriteTapped(let breedID):
            guard !state.favoriteToggleInFlight.contains(breedID) else { return [] }
            guard let existing = state.allBreeds.first(where: { $0.id == breedID }) else { return [] }

            state.favoriteToggleInFlight.insert(breedID)
            let nextValue = !existing.isFavorite

            return [
                .run {
                    do {
                        try dependencies.persistenceClient.setFavorite(breedID, nextValue)
                        return [.favoritePersisted(breedID, nextValue)]
                    } catch {
                        let message = (error as? LocalizedError)?.errorDescription ?? "Failed to update favorite."
                        return [.favoritePersistFailed(breedID, message)]
                    }
                }
            ]

        case .favoritePersisted(let breedID, let isFavorite):
            state.favoriteToggleInFlight.remove(breedID)
            setFavorite(state: &state, breedID: breedID, isFavorite: isFavorite)
            return []

        case .favoritePersistFailed(let breedID, let message):
            state.favoriteToggleInFlight.remove(breedID)
            state.bannerMessage = message
            return []

        case .breedRowAppeared(let breedID):
            var effects: [Effect<Action>] = []

            if state.canLoadMore, !state.isLoadingPage, let index = state.breeds.firstIndex(where: { $0.id == breedID }) {
                let thresholdIndex = max(state.breeds.count - 5, 0)
                if index >= thresholdIndex {
                    effects.append(.send(.loadNextPage))
                }
            }

            if let breed = state.allBreeds.first(where: { $0.id == breedID }),
               breed.imageURL == nil,
               !state.imageHydrationInFlight.contains(breedID) {
                state.imageHydrationInFlight.insert(breedID)
                effects.append(hydrateBreedImageEffect(breedID: breedID, dependencies: dependencies))
            }

            return effects

        case .favoriteFlagsRefreshed(let favoriteIDs):
            setFavoriteFlags(state: &state, favoriteIDs: favoriteIDs)
            return []

        case .breedImageHydrated(let breedID, let imageURL):
            state.imageHydrationInFlight.remove(breedID)
            guard let imageURL else { return [] }
            setBreedImage(state: &state, breedID: breedID, imageURL: imageURL)
            return []

        case .searchQueryChanged(let query):
            state.searchQuery = query
            let token = UUID()
            state.searchToken = token
            return [
                .run {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    return [.applySearchDebounced(token)]
                }
            ]

        case .applySearchDebounced(let token):
            guard token == state.searchToken else { return [] }
            recomputeFilter(state: &state, resetPagination: true)
            return []

        case .cachedBreedsLoaded(let breeds):
            applyLoadedBreeds(state: &state, breeds: breeds)
            return []

        case .networkBreedsLoaded(let breeds):
            state.isLoading = false
            state.isOfflineMode = false
            state.showFatalOfflineState = false
            applyLoadedBreeds(state: &state, breeds: breeds)
            return []

        case .networkFailed(let message, let isOffline):
            state.isLoading = false
            if state.breeds.isEmpty {
                state.errorMessage = message
                state.showFatalOfflineState = isOffline
            } else {
                state.bannerMessage = isOffline ? "Offline mode: showing cached data." : message
                state.isOfflineMode = isOffline
            }
            AppLogger.ui.error("Breeds sync failed: \(message, privacy: .public)")
            return []

        case .loadNextPage:
            state.isLoadingPage = true
            appendNextPage(state: &state)
            state.isLoadingPage = false
            return []
        }
    }

    private static func applyLoadedBreeds(state: inout State, breeds: [Breed]) {
        state.allBreeds = breeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        recomputeFilter(state: &state, resetPagination: true)
    }

    private static func setFavorite(state: inout State, breedID: String, isFavorite: Bool) {
        if let index = state.allBreeds.firstIndex(where: { $0.id == breedID }) {
            state.allBreeds[index].isFavorite = isFavorite
        }
        recomputeFilter(state: &state, resetPagination: false)
    }

    private static func setBreedImage(state: inout State, breedID: String, imageURL: URL) {
        if let index = state.allBreeds.firstIndex(where: { $0.id == breedID }) {
            state.allBreeds[index].imageURL = imageURL
        }
        recomputeFilter(state: &state, resetPagination: false)
    }

    private static func setFavoriteFlags(state: inout State, favoriteIDs: Set<String>) {
        for index in state.allBreeds.indices {
            state.allBreeds[index].isFavorite = favoriteIDs.contains(state.allBreeds[index].id)
        }
        recomputeFilter(state: &state, resetPagination: false)
    }

    private static func recomputeFilter(state: inout State, resetPagination: Bool) {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            state.filteredBreeds = state.allBreeds
        } else {
            state.filteredBreeds = state.allBreeds.filter {
                $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        if resetPagination {
            state.currentPage = 0
            state.breeds = []
            appendNextPage(state: &state)
        } else {
            let displayedCount = min(state.currentPage * state.pageSize, state.filteredBreeds.count)
            state.breeds = Array(state.filteredBreeds.prefix(displayedCount))
            state.canLoadMore = displayedCount < state.filteredBreeds.count
        }
    }

    private static func appendNextPage(state: inout State) {
        guard !state.filteredBreeds.isEmpty else {
            state.breeds = []
            state.canLoadMore = false
            state.currentPage = 0
            return
        }

        let nextCount = min(state.breeds.count + state.pageSize, state.filteredBreeds.count)
        guard nextCount > state.breeds.count else {
            state.canLoadMore = false
            return
        }

        state.breeds = Array(state.filteredBreeds.prefix(nextCount))
        state.currentPage += 1
        state.canLoadMore = state.breeds.count < state.filteredBreeds.count
    }

    private static func loadBreedsEffect(dependencies: AppDependencies) -> Effect<Action> {
        Effect.run {
            var actions: [Action] = []

            do {
                let cached = try dependencies.persistenceClient.loadBreeds()
                if !cached.isEmpty {
                    actions.append(.cachedBreedsLoaded(cached))
                }
            } catch {
                // Ignore cache errors and continue with network.
            }

            do {
                let remote = try await fetchAllBreeds(apiClient: dependencies.apiClient)
                try dependencies.persistenceClient.upsertBreeds(remote, Date())
                let merged = try dependencies.persistenceClient.loadBreeds()
                actions.append(.networkBreedsLoaded(merged))
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Failed to refresh breeds."
                let isOffline = (error as? CatAPIError) == .offline
                actions.append(.networkFailed(message, isOffline))
            }

            return actions
        }
    }

    private static func refreshFavoriteFlagsEffect(dependencies: AppDependencies) -> Effect<Action> {
        Effect.run {
            do {
                let favoriteIDs = try dependencies.persistenceClient.loadFavoriteIDs()
                return [.favoriteFlagsRefreshed(favoriteIDs)]
            } catch {
                AppLogger.ui.error("Favorite refresh failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
    }

    private static func hydrateBreedImageEffect(breedID: String, dependencies: AppDependencies) -> Effect<Action> {
        Effect.run {
            do {
                let imageURL = try await dependencies.apiClient.fetchBreedImage(breedID)
                if let imageURL {
                    try? dependencies.persistenceClient.updateBreedImage(breedID, imageURL)
                }
                return [.breedImageHydrated(breedID, imageURL)]
            } catch {
                AppLogger.api.error("Image hydration failed for \(breedID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return [.breedImageHydrated(breedID, nil)]
            }
        }
    }

    private static func fetchAllBreeds(apiClient: CatAPIClient) async throws -> [Breed] {
        let perPage = 50
        var page = 0
        var allBreeds: [Breed] = []

        while true {
            let chunk = try await apiClient.fetchBreeds(page, perPage)
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
