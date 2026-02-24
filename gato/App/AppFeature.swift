import ComposableArchitecture
import Foundation

enum AppTab: String, CaseIterable, Equatable {
    case breeds
    case favorites
}

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: AppTab = .breeds
        var breeds = BreedsFeature.State()
        var favorites = FavoritesFeature.State()
    }

    enum Action: Equatable {
        case appStarted
        case tabSelected(AppTab)
        case breedsTabBecameActive
        case favoritesTabBecameActive
        case breeds(BreedsFeature.Action)
        case favorites(FavoritesFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.breeds, action: \.breeds) {
            BreedsFeature()
        }

        Scope(state: \.favorites, action: \.favorites) {
            FavoritesFeature()
        }

        Reduce { state, action in
            switch action {
            case .appStarted:
                return activationEffect(for: state.selectedTab)

            case .tabSelected(let tab):
                guard state.selectedTab != tab else { return .none }
                state.selectedTab = tab
                return activationEffect(for: tab)

            case .breedsTabBecameActive:
                return activationEffect(for: .breeds)

            case .favoritesTabBecameActive:
                return activationEffect(for: .favorites)

            case .favorites(.favoritesLoaded), .favorites(.favoritePersisted):
                let favoriteIDs = Set(state.favorites.favorites.map(\.id))
                return .send(.breeds(.favoriteFlagsRefreshed(favoriteIDs)))

            case .breeds, .favorites:
                return .none
            }
        }
    }

    private func activationEffect(for tab: AppTab) -> Effect<Action> {
        switch tab {
        case .breeds:
            return .send(.breeds(.onAppear))

        case .favorites:
            return .send(.favorites(.onAppear))
        }
    }
}
