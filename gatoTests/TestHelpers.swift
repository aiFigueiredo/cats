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

final class LockedBox<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withValue<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
