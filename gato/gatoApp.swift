import CoreData
import SwiftUI

@main
struct gatoApp: App {
    private let persistenceStore: PersistenceStore
    private let dependencies: AppDependencies

    @StateObject private var appStore: Store<AppFeature.State, AppFeature.Action>
    @StateObject private var breedsStore: Store<BreedsFeature.State, BreedsFeature.Action>
    @StateObject private var favoritesStore: Store<FavoritesFeature.State, FavoritesFeature.Action>

    init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITest = environment["UI_TEST_MODE"] == "1"

        let persistenceStore = isUITest ? PersistenceStore.inMemory() : PersistenceStore.live()
        let dependencies = isUITest
            ? AppDependencies.uiTest(context: persistenceStore.container.viewContext, environment: environment)
            : AppDependencies.live(context: persistenceStore.container.viewContext)

        self.persistenceStore = persistenceStore
        self.dependencies = dependencies

        _appStore = StateObject(
            wrappedValue: Store(
                initialState: AppFeature.State(),
                reducer: AppFeature.reduce
            )
        )

        _breedsStore = StateObject(
            wrappedValue: Store(
                initialState: BreedsFeature.State(),
                reducer: { state, action in
                    BreedsFeature.reduce(state: &state, action: action, dependencies: dependencies)
                }
            )
        )

        _favoritesStore = StateObject(
            wrappedValue: Store(
                initialState: FavoritesFeature.State(),
                reducer: { state, action in
                    FavoritesFeature.reduce(state: &state, action: action, dependencies: dependencies)
                }
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                store: appStore,
                breedsStore: breedsStore,
                favoritesStore: favoritesStore,
                imageClient: dependencies.imageClient
            )
        }
    }
}
