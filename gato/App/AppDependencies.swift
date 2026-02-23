import CoreData
import Foundation

struct AppDependencies {
    let apiClient: CatAPIClient
    let persistenceClient: PersistenceClient
    let imageClient: ImageClient

    static func live(context: NSManagedObjectContext) -> AppDependencies {
        AppDependencies(
            apiClient: .live(),
            persistenceClient: .live(context: context),
            imageClient: .live
        )
    }

    static func uiTest(context: NSManagedObjectContext, environment: [String: String]) -> AppDependencies {
        let persistenceClient = PersistenceClient.live(context: context)
        let fixtures = uiTestFixtureBreeds

        if environment["UI_TEST_PRELOAD_CACHE"] == "1" {
            try? persistenceClient.upsertBreeds(fixtures, Date())
        }

        if let favoriteID = environment["UI_TEST_PRELOAD_FAVORITE_ID"], !favoriteID.isEmpty {
            try? persistenceClient.setFavorite(favoriteID, true)
        }

        let isOffline = environment["UI_TEST_OFFLINE"] == "1"
        let apiClient = CatAPIClient(
            fetchBreeds: { page, _ in
                if isOffline { throw CatAPIError.offline }
                return page == 0 ? fixtures : []
            },
            fetchBreedImage: { _ in nil }
        )

        return AppDependencies(
            apiClient: apiClient,
            persistenceClient: persistenceClient,
            imageClient: .live
        )
    }
}

let uiTestFixtureBreeds: [Breed] = [
    Breed(
        id: "abys",
        name: "Abyssinian",
        origin: "Egypt",
        temperament: "Active, Energetic",
        description: "The Abyssinian is easy to care for, and a joy to have in your home.",
        lifeSpan: LifeSpanRange(min: 10, max: 15),
        imageURL: nil,
        isFavorite: false
    ),
    Breed(
        id: "birm",
        name: "Birman",
        origin: "France",
        temperament: "Affectionate, Gentle",
        description: "Birmans are a loving, intelligent breed.",
        lifeSpan: LifeSpanRange(min: 12, max: 16),
        imageURL: nil,
        isFavorite: false
    ),
    Breed(
        id: "beng",
        name: "Bengal",
        origin: "United States",
        temperament: "Alert, Agile",
        description: "Bengals are confident and curious.",
        lifeSpan: LifeSpanRange(min: 10, max: 14),
        imageURL: nil,
        isFavorite: false
    )
]
