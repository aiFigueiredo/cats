import Foundation

struct FavoritesFeature {
    struct State {
        var favorites: [Breed] = []
        var isLoading = false
        var errorMessage: String?
        var favoriteToggleInFlight: Set<String> = []

        var averageLifeSpanMax: Double {
            let maxValues = favorites.compactMap { $0.lifeSpan?.max }
            guard !maxValues.isEmpty else { return 0 }
            let total = maxValues.reduce(0, +)
            return Double(total) / Double(maxValues.count)
        }
    }

    enum Action {
        case onAppear
        case favoritesLoaded([Breed])
        case loadFailed(String)

        case toggleFavoriteTapped(String)
        case favoritePersisted(String)
        case favoritePersistFailed(String, String)
    }

    static func reduce(
        state: inout State,
        action: Action,
        dependencies: AppDependencies
    ) -> [Effect<Action>] {
        switch action {
        case .onAppear:
            state.isLoading = true
            state.errorMessage = nil
            return [
                .run {
                    do {
                        let breeds = try dependencies.persistenceClient.loadBreeds()
                            .filter(\.isFavorite)
                            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        return [.favoritesLoaded(breeds)]
                    } catch {
                        let message = (error as? LocalizedError)?.errorDescription ?? "Failed to load favorites."
                        return [.loadFailed(message)]
                    }
                }
            ]

        case .favoritesLoaded(let favorites):
            state.isLoading = false
            state.favorites = favorites
            return []

        case .loadFailed(let message):
            state.isLoading = false
            state.errorMessage = message
            return []

        case .toggleFavoriteTapped(let breedID):
            guard !state.favoriteToggleInFlight.contains(breedID) else { return [] }
            state.favoriteToggleInFlight.insert(breedID)
            return [
                .run {
                    do {
                        try dependencies.persistenceClient.setFavorite(breedID, false)
                        return [.favoritePersisted(breedID)]
                    } catch {
                        let message = (error as? LocalizedError)?.errorDescription ?? "Failed to update favorite."
                        return [.favoritePersistFailed(breedID, message)]
                    }
                }
            ]

        case .favoritePersisted(let breedID):
            state.favoriteToggleInFlight.remove(breedID)
            state.favorites.removeAll { $0.id == breedID }
            return []

        case .favoritePersistFailed(let breedID, let message):
            state.favoriteToggleInFlight.remove(breedID)
            state.errorMessage = message
            return []
        }
    }
}
