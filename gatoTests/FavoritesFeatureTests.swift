import XCTest
@testable import gato

final class FavoritesFeatureTests: XCTestCase {
    func testAverageLifespanUsesMaxValues() {
        var state = FavoritesFeature.State()
        state.favorites = [
            makeBreed(id: "a", maxLife: 10, isFavorite: true),
            makeBreed(id: "b", maxLife: 16, isFavorite: true),
            makeBreed(id: "c", maxLife: 8, isFavorite: true)
        ]

        XCTAssertEqual(state.averageLifeSpanMax, (10 + 16 + 8) / 3.0, accuracy: 0.0001)
    }

    func testToggleFavoriteRemovesItemOnSuccess() async {
        var state = FavoritesFeature.State()
        state.favorites = [makeBreed(id: "abys", maxLife: 14, isFavorite: true)]

        var persisted: [(String, Bool)] = []
        let deps = AppDependencies(
            apiClient: .mock,
            persistenceClient: .mock(
                loadBreeds: { [] },
                setFavorite: { id, value in
                    persisted.append((id, value))
                }
            ),
            imageClient: .live
        )

        let effects = FavoritesFeature.reduce(state: &state, action: .toggleFavoriteTapped("abys"), dependencies: deps)
        XCTAssertEqual(state.favoriteToggleInFlight, ["abys"])

        let followUpActions = await effects.flatMapAsyncActions()
        for action in followUpActions {
            _ = FavoritesFeature.reduce(state: &state, action: action, dependencies: deps)
        }

        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.0, "abys")
        XCTAssertEqual(persisted.first?.1, false)
        XCTAssertTrue(state.favorites.isEmpty)
    }
}

private func makeBreed(id: String, maxLife: Int, isFavorite: Bool) -> Breed {
    Breed(
        id: id,
        name: id,
        origin: nil,
        temperament: nil,
        description: nil,
        lifeSpan: LifeSpanRange(min: maxLife - 2, max: maxLife),
        imageURL: nil,
        isFavorite: isFavorite
    )
}
