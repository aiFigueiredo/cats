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
}
