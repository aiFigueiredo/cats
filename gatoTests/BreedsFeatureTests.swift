import XCTest
@testable import gato

final class BreedsFeatureTests: XCTestCase {
    func testPaginationLoadsMultiplePages() {
        var state = BreedsFeature.State()
        state.pageSize = 20

        let breeds = (0..<45).map { index in
            Breed(
                id: "id_\(index)",
                name: "Breed \(index)",
                origin: nil,
                temperament: nil,
                description: nil,
                lifeSpan: nil,
                imageURL: nil,
                isFavorite: false
            )
        }

        let deps = AppDependencies.mock
        _ = BreedsFeature.reduce(state: &state, action: .cachedBreedsLoaded(breeds), dependencies: deps)

        XCTAssertEqual(state.breeds.count, 20)
        XCTAssertEqual(state.currentPage, 1)
        XCTAssertTrue(state.canLoadMore)

        _ = BreedsFeature.reduce(state: &state, action: .loadNextPage, dependencies: deps)

        XCTAssertEqual(state.breeds.count, 40)
        XCTAssertEqual(state.currentPage, 2)
        XCTAssertTrue(state.canLoadMore)
    }

    func testSearchFilteringIsCaseInsensitive() {
        var state = BreedsFeature.State()
        let deps = AppDependencies.mock

        _ = BreedsFeature.reduce(
            state: &state,
            action: .cachedBreedsLoaded([
                Breed(id: "1", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false),
                Breed(id: "2", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
            ]),
            dependencies: deps
        )

        let effects = BreedsFeature.reduce(state: &state, action: .searchQueryChanged("ABY"), dependencies: deps)
        let actions = awaitActions(effects)
        for action in actions {
            _ = BreedsFeature.reduce(state: &state, action: action, dependencies: deps)
        }

        XCTAssertEqual(state.breeds.map(\.name), ["Abyssinian"])
    }

    func testFavoriteTogglePersistsBeforeStateUpdate() async {
        var state = BreedsFeature.State()
        state.allBreeds = [
            Breed(id: "1", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        state.filteredBreeds = state.allBreeds
        state.breeds = state.allBreeds
        state.currentPage = 1

        var writeCount = 0
        let deps = AppDependencies(
            apiClient: .mock,
            persistenceClient: .mock(
                loadBreeds: { state.allBreeds },
                setFavorite: { _, _ in writeCount += 1 }
            ),
            imageClient: .live
        )

        let effects = BreedsFeature.reduce(state: &state, action: .toggleFavoriteTapped("1"), dependencies: deps)
        XCTAssertFalse(state.breeds[0].isFavorite)

        let followUps = await effects.flatMapAsyncActions()
        for action in followUps {
            _ = BreedsFeature.reduce(state: &state, action: action, dependencies: deps)
        }

        XCTAssertEqual(writeCount, 1)
        XCTAssertTrue(state.breeds[0].isFavorite)
    }

    func testOnAppearRefreshesFavoriteFlagsAfterExternalFavoriteRemoval() async {
        var state = BreedsFeature.State()
        state.hasLoaded = true
        state.currentPage = 1
        state.pageSize = 20
        state.allBreeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: true),
            Breed(id: "birm", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        state.filteredBreeds = state.allBreeds
        state.breeds = state.allBreeds

        let deps = AppDependencies(
            apiClient: .mock,
            persistenceClient: .mock(
                loadFavoriteIDs: { [] }
            ),
            imageClient: .live
        )

        let effects = BreedsFeature.reduce(state: &state, action: .onAppear, dependencies: deps)
        let followUps = await effects.flatMapAsyncActions()
        for action in followUps {
            _ = BreedsFeature.reduce(state: &state, action: action, dependencies: deps)
        }

        XCTAssertFalse(state.breeds[0].isFavorite)
        XCTAssertFalse(state.allBreeds[0].isFavorite)
    }

    func testBreedRowAppearHydratesMissingImageAndPersistsIt() async {
        var state = BreedsFeature.State()
        state.allBreeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        state.filteredBreeds = state.allBreeds
        state.breeds = state.allBreeds
        state.currentPage = 1

        let expectedURL = URL(string: "https://cdn2.thecatapi.com/images/0XYvRd7oD.jpg")!
        var persistedImage: (String, URL?)?

        let deps = AppDependencies(
            apiClient: CatAPIClient(
                fetchBreeds: { _, _ in [] },
                fetchBreedImage: { breedID in
                    XCTAssertEqual(breedID, "abys")
                    return expectedURL
                }
            ),
            persistenceClient: .mock(
                updateBreedImage: { breedID, imageURL in
                    persistedImage = (breedID, imageURL)
                }
            ),
            imageClient: .live
        )

        let effects = BreedsFeature.reduce(state: &state, action: .breedRowAppeared("abys"), dependencies: deps)
        let followUps = await effects.flatMapAsyncActions()
        for action in followUps {
            _ = BreedsFeature.reduce(state: &state, action: action, dependencies: deps)
        }

        XCTAssertEqual(state.allBreeds.first?.imageURL, expectedURL)
        XCTAssertEqual(state.breeds.first?.imageURL, expectedURL)
        XCTAssertEqual(persistedImage?.0, "abys")
        XCTAssertEqual(persistedImage?.1, expectedURL)
    }

    private func awaitActions(_ effects: [Effect<BreedsFeature.Action>]) -> [BreedsFeature.Action] {
        let group = DispatchGroup()
        var captured: [BreedsFeature.Action] = []
        let lock = NSLock()

        for effect in effects {
            group.enter()
            Task {
                let actions = await effect.operation()
                lock.lock()
                captured.append(contentsOf: actions)
                lock.unlock()
                group.leave()
            }
        }

        group.wait()
        return captured
    }
}
