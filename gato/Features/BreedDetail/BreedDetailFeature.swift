import Foundation

struct BreedDetailFeature {
    struct State: Equatable {
        var breed: Breed
        var isFavoriteToggleInFlight: Bool

        init(breed: Breed, isFavoriteToggleInFlight: Bool = false) {
            self.breed = breed
            self.isFavoriteToggleInFlight = isFavoriteToggleInFlight
        }
    }
}
