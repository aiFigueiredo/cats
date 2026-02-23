import SwiftUI

struct AppView: View {
    @ObservedObject var store: Store<AppFeature.State, AppFeature.Action>

    var body: some View {
        TabView(selection: Binding(
            get: { store.state.selectedTab },
            set: { store.send(.selectTab($0)) }
        )) {
            NavigationStack {
                BreedsView()
            }
            .tabItem {
                Label("Breeds", systemImage: "cat")
            }
            .tag(AppTab.breeds)

            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(AppTab.favorites)
        }
    }
}
