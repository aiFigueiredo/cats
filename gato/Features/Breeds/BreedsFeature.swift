import Foundation

struct BreedsFeature {
    struct State {
        var allBreeds: [Breed] = []
        var breeds: [Breed] = []

        var isLoading = false
        var isLoadingPage = false
        var errorMessage: String?
        var bannerMessage: String?
        var hasLoaded = false

        var currentPage = 0
        var pageSize = 20
        var canLoadMore = false
    }

    enum Action {
        case onAppear
        case retryTapped
        case dismissBanner
        case toggleFavorite(String)
        case breedRowAppeared(String)

        case cachedBreedsLoaded([Breed])
        case networkBreedsLoaded([Breed])
        case networkFailed(String)

        case loadNextPage
    }

    static func reduce(
        state: inout State,
        action: Action,
        dependencies: AppDependencies
    ) -> [Effect<Action>] {
        switch action {
        case .onAppear:
            guard !state.hasLoaded else { return [] }
            state.hasLoaded = true
            state.isLoading = true
            state.errorMessage = nil
            return [loadBreedsEffect(dependencies: dependencies)]

        case .retryTapped:
            state.isLoading = true
            state.errorMessage = nil
            return [loadBreedsEffect(dependencies: dependencies)]

        case .dismissBanner:
            state.bannerMessage = nil
            return []

        case .toggleFavorite(let breedID):
            toggleFavoriteLocally(state: &state, breedID: breedID)
            return []

        case .breedRowAppeared(let breedID):
            guard state.canLoadMore, !state.isLoadingPage else { return [] }
            guard let index = state.breeds.firstIndex(where: { $0.id == breedID }) else { return [] }

            let thresholdIndex = max(state.breeds.count - 5, 0)
            if index >= thresholdIndex {
                return [.send(.loadNextPage)]
            }
            return []

        case .cachedBreedsLoaded(let breeds):
            applyLoadedBreeds(state: &state, breeds: breeds)
            return []

        case .networkBreedsLoaded(let breeds):
            state.isLoading = false
            applyLoadedBreeds(state: &state, breeds: breeds)
            return []

        case .networkFailed(let message):
            state.isLoading = false
            if state.breeds.isEmpty {
                state.errorMessage = message
            } else {
                state.bannerMessage = message
            }
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
        state.currentPage = 0
        state.breeds = []
        appendNextPage(state: &state)
    }

    private static func appendNextPage(state: inout State) {
        guard !state.allBreeds.isEmpty else {
            state.breeds = []
            state.canLoadMore = false
            state.currentPage = 0
            return
        }

        let nextCount = min(state.breeds.count + state.pageSize, state.allBreeds.count)
        guard nextCount > state.breeds.count else {
            state.canLoadMore = false
            return
        }

        state.breeds = Array(state.allBreeds.prefix(nextCount))
        state.currentPage += 1
        state.canLoadMore = state.breeds.count < state.allBreeds.count
    }

    private static func toggleFavoriteLocally(state: inout State, breedID: String) {
        if let allIndex = state.allBreeds.firstIndex(where: { $0.id == breedID }) {
            state.allBreeds[allIndex].isFavorite.toggle()
        }

        if let listIndex = state.breeds.firstIndex(where: { $0.id == breedID }) {
            state.breeds[listIndex].isFavorite.toggle()
        }
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
                actions.append(.networkFailed(message))
            }

            return actions
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
