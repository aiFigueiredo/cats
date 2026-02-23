import SwiftUI

@main
struct gatoApp: App {
    @StateObject private var store = Store(
        initialState: AppFeature.State(),
        reducer: AppFeature.reduce
    )

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
