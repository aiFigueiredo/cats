import ComposableArchitecture
import Foundation

@Reducer
struct BreedDetailFeature {
    @ObservableState
    struct State: Equatable {
        var breed: Breed
        var isFavoriteToggleInFlight: Bool

        init(breed: Breed, isFavoriteToggleInFlight: Bool = false) {
            self.breed = breed
            self.isFavoriteToggleInFlight = isFavoriteToggleInFlight
        }
    }

    enum Action: Equatable {
        case sourceUpdated(Breed, Bool)
        case favoriteButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .sourceUpdated(breed, inFlight):
                state.breed = breed
                state.isFavoriteToggleInFlight = inFlight
                return .none

            case .favoriteButtonTapped:
                return .none
            }
        }
    }
}
