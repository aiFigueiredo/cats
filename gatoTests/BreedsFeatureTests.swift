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
                imageURL: URL(string: "https://example.com/\(index).png"),
                isFavorite: false
            )
        }
        let sorted = breeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = .mock
            $0.persistenceClient = .mock()
        }

        await store.send(.cachedBreedsLoaded(breeds)) {
            $0.preparationGeneration = 1
            $0.pendingPreparedBreedsCount = breeds.count
        }

        await store.receive(
            .preparedBreedsViewState(
                BreedsFeature.PreparedBreedsViewState(
                    breedsByID: Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) }),
                    orderedBreedIDs: sorted.map(\.id),
                    filteredBreedIDs: sorted.map(\.id),
                    visibleBreedIDs: Array(sorted.prefix(20).map(\.id)),
                    visibleCount: 20,
                    canLoadMore: true
                ),
                1
            )
        ) {
            $0.breedsByID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
            $0.orderedBreedIDs = sorted.map(\.id)
            $0.filteredBreedIDs = sorted.map(\.id)
            $0.visibleBreedIDs = Array(sorted.prefix(20).map(\.id))
            $0.visibleCount = 20
            $0.canLoadMore = true
            $0.pendingPreparedBreedsCount = 0
        }

        await store.send(.loadNextPage) {
            $0.visibleBreedIDs = Array(sorted.prefix(40).map(\.id))
            $0.visibleCount = 40
            $0.canLoadMore = true
        }
    }

    @Test("search filtering is case-insensitive")
    func searchFilteringIsCaseInsensitive() async {
        let breeds = [
            Breed(id: "1", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: URL(string: "https://example.com/1.png"), isFavorite: false),
            Breed(id: "2", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: URL(string: "https://example.com/2.png"), isFavorite: false)
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
            $0.preparationGeneration = 1
            $0.pendingPreparedBreedsCount = breeds.count
        }

        await store.receive(
            .preparedBreedsViewState(
                BreedsFeature.PreparedBreedsViewState(
                    breedsByID: Dictionary(uniqueKeysWithValues: breeds.map { ($0.id, $0) }),
                    orderedBreedIDs: breeds.map(\.id),
                    filteredBreedIDs: ["1"],
                    visibleBreedIDs: ["1"],
                    visibleCount: 1,
                    canLoadMore: false
                ),
                1
            )
        ) {
            $0.breedsByID = Dictionary(uniqueKeysWithValues: breeds.map { ($0.id, $0) })
            $0.orderedBreedIDs = breeds.map(\.id)
            $0.filteredBreedIDs = ["1"]
            $0.visibleBreedIDs = ["1"]
            $0.visibleCount = 1
            $0.canLoadMore = false
            $0.pendingPreparedBreedsCount = 0
        }
    }

    @Test("favorite toggle persists before state update")
    func favoriteTogglePersistsBeforeStateUpdate() async {
        let writeCount = LockedBox(0)

        var initialState = BreedsFeature.State()
        initialState.breedsByID = [
            "1": Breed(id: "1", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        initialState.orderedBreedIDs = ["1"]
        initialState.filteredBreedIDs = ["1"]
        initialState.visibleBreedIDs = ["1"]
        initialState.visibleCount = 1
        initialState.canLoadMore = false

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
            $0.breedsByID["1"]?.isFavorite = true
        }

        #expect(writeCount.withValue { $0 } == 1)
    }

    @Test("onAppear refreshes favorite flags after external favorite removal")
    func onAppearRefreshesFavoriteFlagsAfterExternalFavoriteRemoval() async {
        var initialState = BreedsFeature.State()
        initialState.hasLoaded = true
        initialState.breedsByID = [
            "abys": Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: true),
            "birm": Breed(id: "birm", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]
        initialState.orderedBreedIDs = ["abys", "birm"]
        initialState.filteredBreedIDs = ["abys", "birm"]
        initialState.visibleBreedIDs = ["abys", "birm"]
        initialState.visibleCount = 2
        initialState.canLoadMore = false

        let store = TestStore(initialState: initialState) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = .mock
            $0.persistenceClient = .mock(loadFavoriteIDs: { [] })
        }

        await store.send(.onAppear)

        await store.receive(.favoriteFlagsRefreshed([])) {
            $0.breedsByID["abys"]?.isFavorite = false
        }
    }

    @Test("cached load hydrates missing image and persists it in a batch flush")
    func cachedLoadHydratesMissingImageAndPersistsItInBatchFlush() async {
        let expectedURL = URL(string: "https://cdn2.thecatapi.com/images/0XYvRd7oD.jpg")!
        let persistedImages = LockedBox<[String: URL?]>([:])

        let breeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]

        let store = TestStore(initialState: BreedsFeature.State()) {
            BreedsFeature()
        } withDependencies: {
            $0.continuousClock = ContinuousClock()
            $0.apiClient = CatAPIClient(
                fetchBreeds: { _, _ in [] },
                fetchBreedImage: { breedID in
                    #expect(breedID == "abys")
                    return expectedURL
                }
            )
            $0.persistenceClient = .mock(
                updateBreedImagesBatch: { updates, _ in
                    persistedImages.withValue { $0.merge(updates) { _, new in new } }
                }
            )
        }

        await store.send(.cachedBreedsLoaded(breeds)) {
            $0.preparationGeneration = 1
            $0.pendingPreparedBreedsCount = breeds.count
        }

        await store.receive(
            .preparedBreedsViewState(
                BreedsFeature.PreparedBreedsViewState(
                    breedsByID: ["abys": breeds[0]],
                    orderedBreedIDs: ["abys"],
                    filteredBreedIDs: ["abys"],
                    visibleBreedIDs: ["abys"],
                    visibleCount: 1,
                    canLoadMore: false
                ),
                1
            )
        ) {
            $0.breedsByID = ["abys": breeds[0]]
            $0.orderedBreedIDs = ["abys"]
            $0.filteredBreedIDs = ["abys"]
            $0.visibleBreedIDs = ["abys"]
            $0.visibleCount = 1
            $0.canLoadMore = false
            $0.pendingPreparedBreedsCount = 0
            $0.imageHydrationInFlight = ["abys"]
        }

        await store.receive(.breedImageHydrated("abys", expectedURL)) {
            $0.imageHydrationInFlight = []
            $0.breedsByID["abys"]?.imageURL = expectedURL
            $0.pendingImagePersistence = ["abys": expectedURL]
        }

        await store.receive(.flushPendingImagePersistence) {
            $0.pendingImagePersistence = [:]
        }

        let saved = persistedImages.withValue { $0 }
        #expect((saved["abys"] ?? nil) == expectedURL)
    }
}
