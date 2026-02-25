import ComposableArchitecture
import CoreData
import Foundation
import Testing
@testable import gato

@Suite("Integration Sync")
@MainActor
struct IntegrationSyncTests {
    @Test("sync persists and reloads from cache when offline")
    func syncPersistsAndReloadsFromCacheWhenOffline() async throws {
        let store = PersistenceStore.inMemory()
        let persistence = PersistenceClient.live(context: store.container.viewContext)

        let expectedBreeds = [
            Breed(id: "abys", name: "Abyssinian", origin: "Egypt", temperament: "Active", description: "Friendly", lifeSpan: LifeSpanRange(min: 10, max: 15), imageURL: URL(string: "https://example.com/abys.png"), isFavorite: false),
            Breed(id: "birm", name: "Birman", origin: "France", temperament: "Calm", description: "Gentle", lifeSpan: LifeSpanRange(min: 12, max: 16), imageURL: URL(string: "https://example.com/birm.png"), isFavorite: false)
        ]

        let onlineStore = TestStore(initialState: BreedsFeature.State()) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = CatAPIClient(
                fetchBreeds: { page, _ in
                    page == 0 ? expectedBreeds : []
                },
                fetchBreedImage: { _ in nil }
            )
            $0.persistenceClient = persistence
        }

        await onlineStore.send(.onAppear) {
            $0.hasLoaded = true
            $0.isLoading = true
            $0.errorMessage = nil
            $0.showFatalOfflineState = false
        }

        let sortedExpected = expectedBreeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        await onlineStore.receive(.networkBreedsLoaded(sortedExpected)) {
            $0.isLoading = false
            $0.isOfflineMode = false
            $0.showFatalOfflineState = false
            $0.breedsByID = Dictionary(uniqueKeysWithValues: sortedExpected.map { ($0.id, $0) })
            $0.orderedBreedIDs = sortedExpected.map(\.id)
            $0.filteredBreedIDs = sortedExpected.map(\.id)
            $0.visibleBreedIDs = sortedExpected.map(\.id)
            $0.visibleCount = 2
            $0.canLoadMore = false
        }

        let offlineStore = TestStore(initialState: BreedsFeature.State()) {
            BreedsFeature()
        } withDependencies: {
            $0.apiClient = CatAPIClient(
                fetchBreeds: { _, _ in throw CatAPIError.offline },
                fetchBreedImage: { _ in nil }
            )
            $0.persistenceClient = persistence
        }

        await offlineStore.send(.onAppear) {
            $0.hasLoaded = true
            $0.isLoading = true
            $0.errorMessage = nil
            $0.showFatalOfflineState = false
        }

        await offlineStore.receive(.cachedBreedsLoaded(sortedExpected)) {
            $0.breedsByID = Dictionary(uniqueKeysWithValues: sortedExpected.map { ($0.id, $0) })
            $0.orderedBreedIDs = sortedExpected.map(\.id)
            $0.filteredBreedIDs = sortedExpected.map(\.id)
            $0.visibleBreedIDs = sortedExpected.map(\.id)
            $0.visibleCount = 2
            $0.canLoadMore = false
        }

        await offlineStore.receive(.networkFailed("No internet connection.", true)) {
            $0.isLoading = false
            $0.bannerMessage = "Offline mode: showing cached data."
            $0.isOfflineMode = true
        }

        #expect(Set(offlineStore.state.breedsByID.keys) == Set(expectedBreeds.map(\.id)))
        #expect(offlineStore.state.bannerMessage != nil)
    }

    @Test("favorite persistence CRUD integration")
    func favoritePersistenceCRUDIntegration() throws {
        let store = PersistenceStore.inMemory()
        let persistence = PersistenceClient.live(context: store.container.viewContext)

        let breeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]

        try persistence.upsertBreeds(breeds, Date())
        try persistence.setFavorite("abys", true)

        #expect(try persistence.loadFavoriteIDs() == ["abys"])
        #expect(try persistence.isFavorite("abys"))

        try persistence.setFavorite("abys", false)

        #expect(try persistence.loadFavoriteIDs() == [])
        #expect(!(try persistence.isFavorite("abys")))
    }

    @Test("loadFavorites returns only favorite breeds sorted by name")
    func loadFavoritesReturnsOnlyFavoriteBreedsSortedByName() throws {
        let store = PersistenceStore.inMemory()
        let persistence = PersistenceClient.live(context: store.container.viewContext)

        let breeds = [
            Breed(id: "beng", name: "Bengal", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false),
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false),
            Breed(id: "birm", name: "Birman", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]

        try persistence.upsertBreeds(breeds, Date())
        try persistence.setFavorite("birm", true)
        try persistence.setFavorite("abys", true)

        let favorites = try persistence.loadFavorites()
        #expect(favorites.map(\.id) == ["abys", "birm"])
        #expect(favorites.allSatisfy { $0.isFavorite })
    }

    @Test("upsert preserves existing image URL when incoming payload omits image")
    func upsertPreservesExistingImageURLWhenIncomingPayloadOmitsImage() throws {
        let store = PersistenceStore.inMemory()
        let persistence = PersistenceClient.live(context: store.container.viewContext)

        let cachedURL = URL(string: "https://cdn2.thecatapi.com/images/cached.jpg")!
        let cached = Breed(
            id: "abys",
            name: "Abyssinian",
            origin: "Egypt",
            temperament: "Active",
            description: "Cached",
            lifeSpan: LifeSpanRange(min: 10, max: 14),
            imageURL: cachedURL,
            isFavorite: false
        )

        let remoteWithoutImage = Breed(
            id: "abys",
            name: "Abyssinian",
            origin: "Egypt",
            temperament: "Active",
            description: "Remote",
            lifeSpan: LifeSpanRange(min: 10, max: 15),
            imageURL: nil,
            isFavorite: false
        )

        try persistence.upsertBreeds([cached], Date())
        try persistence.upsertBreeds([remoteWithoutImage], Date().addingTimeInterval(1))

        let loaded = try persistence.loadBreeds()
        let persisted = try #require(loaded.first(where: { $0.id == "abys" }))
        #expect(persisted.imageURL == cachedURL)
    }
}
