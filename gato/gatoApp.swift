import ComposableArchitecture
import CoreData
import SwiftUI

@main
struct gatoApp: App {
    private let persistenceStore: PersistenceStore
    private let imageClient: ImageClient
    private let store: StoreOf<AppFeature>

    init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITest = environment["UI_TEST_MODE"] == "1"

        let persistenceStore = isUITest ? PersistenceStore.inMemory() : PersistenceStore.live()
        let dependencies = isUITest
            ? AppDependencies.uiTest(context: persistenceStore.container.viewContext, environment: environment)
            : AppDependencies.live(context: persistenceStore.container.viewContext)

        self.persistenceStore = persistenceStore
        self.imageClient = dependencies.imageClient

        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.apiClient = dependencies.apiClient
            $0.persistenceClient = dependencies.persistenceClient
            $0.imageClient = dependencies.imageClient
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store, imageClient: imageClient)
        }
    }
}
