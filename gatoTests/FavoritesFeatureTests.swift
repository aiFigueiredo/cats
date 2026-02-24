import ComposableArchitecture
import Testing
@testable import gato

@Suite("FavoritesFeature")
@MainActor
struct FavoritesFeatureTests {
    @Test("average lifespan uses max values")
    func averageLifespanUsesMaxValues() {
        var state = FavoritesFeature.State()
        state.favorites = [
            makeBreed(id: "a", maxLife: 10, isFavorite: true),
            makeBreed(id: "b", maxLife: 16, isFavorite: true),
            makeBreed(id: "c", maxLife: 8, isFavorite: true)
        ]

        let maxValues = state.favorites.compactMap { $0.lifeSpan?.max }
        let average = Double(maxValues.reduce(0, +)) / Double(maxValues.count)
        #expect(average == (10 + 16 + 8) / 3.0)
    }

    @Test("toggle favorite removes item on success")
    func toggleFavoriteRemovesItemOnSuccess() async {
        let persisted = LockedBox<[(String, Bool)]>([])

        var initialState = FavoritesFeature.State()
        initialState.favorites = [makeBreed(id: "abys", maxLife: 14, isFavorite: true)]

        let store = TestStore(initialState: initialState) {
            FavoritesFeature()
        } withDependencies: {
            $0.persistenceClient = .mock(
                setFavorite: { id, value in
                    persisted.withValue { $0.append((id, value)) }
                }
            )
            $0.apiClient = .mock
        }

        await store.send(.toggleFavoriteTapped("abys")) {
            $0.favoriteToggleInFlight = ["abys"]
        }

        await store.receive(.favoritePersisted("abys")) {
            $0.favoriteToggleInFlight = []
            $0.favorites = []
        }

        let writes = persisted.withValue { $0 }
        #expect(writes.count == 1)
        #expect(writes.first?.0 == "abys")
        #expect(writes.first?.1 == false)
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
