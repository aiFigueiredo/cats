import ComposableArchitecture
import Foundation

private enum DependencyFailure: Error, LocalizedError {
    case unimplemented(String)

    var errorDescription: String? {
        switch self {
        case .unimplemented(let detail):
            return "Unimplemented dependency: \(detail)"
        }
    }
}

extension CatAPIClient {
    static func unimplemented(_ label: String = "CatAPIClient") -> CatAPIClient {
        CatAPIClient(
            fetchBreeds: { _, _ in
                throw DependencyFailure.unimplemented("\(label).fetchBreeds")
            },
            fetchBreedImage: { _ in
                throw DependencyFailure.unimplemented("\(label).fetchBreedImage")
            }
        )
    }
}

extension PersistenceClient {
    static func unimplemented(_ label: String = "PersistenceClient") -> PersistenceClient {
        PersistenceClient(
            loadBreeds: {
                throw DependencyFailure.unimplemented("\(label).loadBreeds")
            },
            upsertBreeds: { _, _ in
                throw DependencyFailure.unimplemented("\(label).upsertBreeds")
            },
            updateBreedImage: { _, _ in
                throw DependencyFailure.unimplemented("\(label).updateBreedImage")
            },
            loadFavoriteIDs: {
                throw DependencyFailure.unimplemented("\(label).loadFavoriteIDs")
            },
            setFavorite: { _, _ in
                throw DependencyFailure.unimplemented("\(label).setFavorite")
            },
            isFavorite: { _ in
                throw DependencyFailure.unimplemented("\(label).isFavorite")
            }
        )
    }
}

private enum CatAPIClientKey: DependencyKey {
    static let liveValue: CatAPIClient = .unimplemented()
    static let testValue: CatAPIClient = .unimplemented("Test CatAPIClient")
}

private enum PersistenceClientKey: DependencyKey {
    static let liveValue: PersistenceClient = .unimplemented()
    static let testValue: PersistenceClient = .unimplemented("Test PersistenceClient")
}

private enum ImageClientKey: DependencyKey {
    static let liveValue: ImageClient = .live
    static let testValue: ImageClient = .live
}

extension DependencyValues {
    var apiClient: CatAPIClient {
        get { self[CatAPIClientKey.self] }
        set { self[CatAPIClientKey.self] = newValue }
    }

    var persistenceClient: PersistenceClient {
        get { self[PersistenceClientKey.self] }
        set { self[PersistenceClientKey.self] = newValue }
    }

    var imageClient: ImageClient {
        get { self[ImageClientKey.self] }
        set { self[ImageClientKey.self] = newValue }
    }
}
