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
        case onAppear
        case selectTab(AppTab)
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
            case .onAppear:
                return effectForSelectedTab(state: state, tab: state.selectedTab)

            case .selectTab(let tab):
                state.selectedTab = tab
                return effectForSelectedTab(state: state, tab: tab)

            case .favorites(.favoritesLoaded), .favorites(.favoritePersisted):
                let favoriteIDs = Set(state.favorites.favorites.map(\.id))
                return .send(.breeds(.favoriteFlagsRefreshed(favoriteIDs)))

            case .breeds, .favorites:
                return .none
            }
        }
    }

    private func effectForSelectedTab(state: State, tab: AppTab) -> Effect<Action> {
        switch tab {
        case .breeds:
            let favoriteIDs = Set(state.favorites.favorites.map(\.id))
            return .concatenate(
                .send(.breeds(.favoriteFlagsRefreshed(favoriteIDs))),
                .send(.breeds(.onAppear))
            )

        case .favorites:
            return .send(.favorites(.onAppear))
        }
    }
}
