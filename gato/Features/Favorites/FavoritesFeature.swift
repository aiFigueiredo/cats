import ComposableArchitecture
import Foundation

@Reducer
struct FavoritesFeature {
    @ObservableState
    struct State: Equatable {
        var favorites: [Breed] = []
        var isLoading = false
        var errorMessage: String?
        var favoriteToggleInFlight: Set<String> = []
    }

    enum Action: Equatable {
        case onAppear
        case favoritesLoaded([Breed])
        case loadFailed(String)

        case toggleFavoriteTapped(String)
        case favoritePersisted(String)
        case favoritePersistFailed(String, String)
    }

    @Dependency(\.persistenceClient) var persistenceClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                do {
                    let breeds = try persistenceClient.loadBreeds()
                        .filter(\.isFavorite)
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    return .send(.favoritesLoaded(breeds))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? "Failed to load favorites."
                    return .send(.loadFailed(message))
                }

            case .favoritesLoaded(let favorites):
                state.isLoading = false
                state.favorites = favorites
                return .none

            case .loadFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .toggleFavoriteTapped(let breedID):
                guard !state.favoriteToggleInFlight.contains(breedID) else { return .none }
                state.favoriteToggleInFlight.insert(breedID)
                do {
                    try persistenceClient.setFavorite(breedID, false)
                    return .send(.favoritePersisted(breedID))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? "Failed to update favorite."
                    return .send(.favoritePersistFailed(breedID, message))
                }

            case .favoritePersisted(let breedID):
                state.favoriteToggleInFlight.remove(breedID)
                state.favorites.removeAll { $0.id == breedID }
                return .none

            case .favoritePersistFailed(let breedID, let message):
                state.favoriteToggleInFlight.remove(breedID)
                state.errorMessage = message
                return .none
            }
        }
    }
}
