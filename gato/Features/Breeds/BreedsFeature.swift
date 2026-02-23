import Foundation

struct BreedsFeature {
    struct State {
        var breeds: [Breed] = []
        var isLoading = false
        var errorMessage: String?
        var bannerMessage: String?
        var hasLoaded = false
    }

    enum Action {
        case onAppear
        case retryTapped
        case dismissBanner
        case toggleFavorite(String)
        case cachedBreedsLoaded([Breed])
        case networkBreedsLoaded([Breed])
        case networkFailed(String)
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
            guard let index = state.breeds.firstIndex(where: { $0.id == breedID }) else { return [] }
            state.breeds[index].isFavorite.toggle()
            return []

        case .cachedBreedsLoaded(let breeds):
            state.breeds = breeds
            return []

        case .networkBreedsLoaded(let breeds):
            state.isLoading = false
            state.breeds = breeds
            return []

        case .networkFailed(let message):
            state.isLoading = false
            if state.breeds.isEmpty {
                state.errorMessage = message
            } else {
                state.bannerMessage = message
            }
            return []
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
                // Do not block sync; network may still succeed.
            }

            do {
                let remote = try await dependencies.apiClient.fetchBreeds(0, 40)
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
}
