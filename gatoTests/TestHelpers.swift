import Foundation
@testable import gato

extension CatAPIClient {
    static var mock: CatAPIClient {
        CatAPIClient(
            fetchBreeds: { _, _ in [] },
            fetchBreedImage: { _ in nil }
        )
    }
}

extension PersistenceClient {
    static func mock(
        loadBreeds: @escaping () throws -> [Breed] = { [] },
        upsertBreeds: @escaping (_ breeds: [Breed], _ now: Date) throws -> Void = { _, _ in },
        updateBreedImage: @escaping (_ breedID: String, _ imageURL: URL?) throws -> Void = { _, _ in },
        loadFavoriteIDs: @escaping () throws -> Set<String> = { [] },
        setFavorite: @escaping (_ breedID: String, _ isFavorite: Bool) throws -> Void = { _, _ in },
        isFavorite: @escaping (_ breedID: String) throws -> Bool = { _ in false }
    ) -> PersistenceClient {
        PersistenceClient(
            loadBreeds: loadBreeds,
            upsertBreeds: upsertBreeds,
            updateBreedImage: updateBreedImage,
            loadFavoriteIDs: loadFavoriteIDs,
            setFavorite: setFavorite,
            isFavorite: isFavorite
        )
    }
}

extension AppDependencies {
    static var mock: AppDependencies {
        AppDependencies(
            apiClient: .mock,
            persistenceClient: .mock(),
            imageClient: .live
        )
    }
}

extension Array where Element == Effect<BreedsFeature.Action> {
    func flatMapAsyncActions() async -> [BreedsFeature.Action] {
        var all: [BreedsFeature.Action] = []
        for effect in self {
            let next = await effect.operation()
            all.append(contentsOf: next)
        }
        return all
    }
}

extension Array where Element == Effect<FavoritesFeature.Action> {
    func flatMapAsyncActions() async -> [FavoritesFeature.Action] {
        var all: [FavoritesFeature.Action] = []
        for effect in self {
            let next = await effect.operation()
            all.append(contentsOf: next)
        }
        return all
    }
}
