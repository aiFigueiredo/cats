import CoreData
import XCTest
@testable import gato

final class IntegrationSyncTests: XCTestCase {
    func testSyncPersistsAndReloadsFromCacheWhenOffline() async throws {
        let store = PersistenceStore.inMemory()
        let persistence = PersistenceClient.live(context: store.container.viewContext)

        let expectedBreeds = [
            Breed(id: "abys", name: "Abyssinian", origin: "Egypt", temperament: "Active", description: "Friendly", lifeSpan: LifeSpanRange(min: 10, max: 15), imageURL: nil, isFavorite: false),
            Breed(id: "birm", name: "Birman", origin: "France", temperament: "Calm", description: "Gentle", lifeSpan: LifeSpanRange(min: 12, max: 16), imageURL: nil, isFavorite: false)
        ]

        let onlineDependencies = AppDependencies(
            apiClient: CatAPIClient(
                fetchBreeds: { page, _ in
                    page == 0 ? expectedBreeds : []
                },
                fetchBreedImage: { _ in nil }
            ),
            persistenceClient: persistence,
            imageClient: .live
        )

        var onlineState = BreedsFeature.State()
        let onlineEffects = BreedsFeature.reduce(state: &onlineState, action: .onAppear, dependencies: onlineDependencies)
        for action in await onlineEffects.flatMapAsyncActions() {
            _ = BreedsFeature.reduce(state: &onlineState, action: action, dependencies: onlineDependencies)
        }

        XCTAssertEqual(Set(onlineState.allBreeds.map(\.id)), Set(expectedBreeds.map(\.id)))

        let offlineDependencies = AppDependencies(
            apiClient: CatAPIClient(
                fetchBreeds: { _, _ in throw CatAPIError.offline },
                fetchBreedImage: { _ in nil }
            ),
            persistenceClient: persistence,
            imageClient: .live
        )

        var offlineState = BreedsFeature.State()
        let offlineEffects = BreedsFeature.reduce(state: &offlineState, action: .onAppear, dependencies: offlineDependencies)
        for action in await offlineEffects.flatMapAsyncActions() {
            _ = BreedsFeature.reduce(state: &offlineState, action: action, dependencies: offlineDependencies)
        }

        XCTAssertEqual(Set(offlineState.allBreeds.map(\.id)), Set(expectedBreeds.map(\.id)))
        XCTAssertNotNil(offlineState.bannerMessage)
    }

    func testFavoritePersistenceCRUDIntegration() throws {
        let store = PersistenceStore.inMemory()
        let persistence = PersistenceClient.live(context: store.container.viewContext)

        let breeds = [
            Breed(id: "abys", name: "Abyssinian", origin: nil, temperament: nil, description: nil, lifeSpan: nil, imageURL: nil, isFavorite: false)
        ]

        try persistence.upsertBreeds(breeds, Date())
        try persistence.setFavorite("abys", true)

        XCTAssertEqual(try persistence.loadFavoriteIDs(), ["abys"])
        XCTAssertTrue(try persistence.isFavorite("abys"))

        try persistence.setFavorite("abys", false)

        XCTAssertEqual(try persistence.loadFavoriteIDs(), [])
        XCTAssertFalse(try persistence.isFavorite("abys"))
    }
}
