import ComposableArchitecture
import Foundation
import Testing
@testable import gato

@Suite("BreedsFeature")
@MainActor
struct BreedsFeatureTests {
    @Test("pagination loads multiple pages")
    func paginationLoadsMultiplePages() async {
        var initialState = BreedsFeature.State()
        initialState.pageSize = 20

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

        let sortedBreeds = breeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = .mock
            $0.persistenceClient = .mock()
        }

        await store.send(.cachedBreedsLoaded(breeds)) {
            $0.allBreeds = sortedBreeds
            $0.filteredBreeds = sortedBreeds
            $0.breeds = Array(sortedBreeds.prefix(20))
            $0.currentPage = 1
            $0.canLoadMore = true
        }

        await store.send(.loadNextPage) {
            $0.isLoadingPage = true
            $0.breeds = Array(sortedBreeds.prefix(40))
            $0.isLoadingPage = false
            $0.currentPage = 2
            $0.canLoadMore = true
        }
    }

    @Test("search filtering is case-insensitive")
    func searchFilteringIsCaseInsensitive() async {
        let breeds = [
            Breed(id: "1", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false),
            Breed(id: "2", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]

        var initialState = BreedsFeature.State()
        initialState.searchQuery = "ABY"

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = .mock
            $0.persistenceClient = .mock()
        }

        await store.send(.cachedBreedsLoaded(breeds)) {
            $0.allBreeds = breeds
            $0.filteredBreeds = [breeds[0]]
            $0.breeds = [breeds[0]]
            $0.currentPage = 1
            $0.canLoadMore = false
        }
    }

    @Test("favorite toggle persists before state update")
    func favoriteTogglePersistsBeforeStateUpdate() async {
        let writeCount = LockedBox(0)

        var initialState = BreedsFeature.State()
        initialState.allBreeds = [
            Breed(id: "1", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        initialState.filteredBreeds = initialState.allBreeds
        initialState.breeds = initialState.allBreeds
        initialState.currentPage = 1

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = .mock
            $0.persistenceClient = .mock(
                setFavorite: { _, _ in
                    writeCount.withValue { $0 += 1 }
                }
            )
        }

        await store.send(.toggleFavoriteTapped("1")) {
            $0.favoriteToggleInFlight = ["1"]
        }

        await store.receive(.favoritePersisted("1", true)) {
            $0.favoriteToggleInFlight = []
            $0.allBreeds[0].isFavorite = true
            $0.filteredBreeds[0].isFavorite = true
            $0.breeds[0].isFavorite = true
        }

        #expect(writeCount.withValue { $0 } == 1)
    }

    @Test("onAppear refreshes favorite flags after external favorite removal")
    func onAppearRefreshesFavoriteFlagsAfterExternalFavoriteRemoval() async {
        var initialState = BreedsFeature.State()
        initialState.hasLoaded = true
        initialState.currentPage = 1
        initialState.pageSize = 20
        initialState.allBreeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: true),
            Breed(id: "birm", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        initialState.filteredBreeds = initialState.allBreeds
        initialState.breeds = initialState.allBreeds

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = .mock
            $0.persistenceClient = .mock(loadFavoriteIDs: { [] })
        }

        await store.send(.onAppear)

        await store.receive(.favoriteFlagsRefreshed([])) {
            $0.allBreeds[0].isFavorite = false
            $0.filteredBreeds[0].isFavorite = false
            $0.breeds[0].isFavorite = false
        }
    }

    @Test("breed row appear hydrates missing image and persists it")
    func breedRowAppearHydratesMissingImageAndPersistsIt() async {
        let expectedURL = URL(string: "https://cdn2.thecatapi.com/images/0XYvRd7oD.jpg")!
        let persistedImage = LockedBox<(String, URL?)?>(nil)

        var initialState = BreedsFeature.State()
        initialState.allBreeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        initialState.filteredBreeds = initialState.allBreeds
        initialState.breeds = initialState.allBreeds
        initialState.currentPage = 1

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = CatAPIClient(
                fetchBreeds: { _, _ in [] },
                fetchBreedImage: { breedID in
                    #expect(breedID == "abys")
                    return expectedURL
                }
            )
            $0.persistenceClient = .mock(
                updateBreedImage: { breedID, imageURL in
                    persistedImage.withValue { $0 = (breedID, imageURL) }
                }
            )
        }

        await store.send(.breedRowAppeared("abys")) {
            $0.imageHydrationInFlight = ["abys"]
        }

        await store.receive(.breedImageHydrated("abys", expectedURL)) {
            $0.imageHydrationInFlight = []
            $0.allBreeds[0].imageURL = expectedURL
            $0.filteredBreeds[0].imageURL = expectedURL
            $0.breeds[0].imageURL = expectedURL
        }

        let saved = persistedImage.withValue { $0 }
        #expect(saved?.0 == "abys")
        #expect(saved?.1 == expectedURL)
    }
}
