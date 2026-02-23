import SwiftUI

struct AppView: View {
    @ObservedObject var store: Store<AppFeature.State, AppFeature.Action>
    @ObservedObject var breedsStore: Store<BreedsFeature.State, BreedsFeature.Action>
    @ObservedObject var favoritesStore: Store<FavoritesFeature.State, FavoritesFeature.Action>

    var body: some View {
        TabView(selection: Binding(
            get: { store.state.selectedTab },
            set: { store.send(.selectTab($0)) }
        )) {
            NavigationStack {
                BreedsView(store: breedsStore)
            }
            .tabItem {
                Label("Breeds", systemImage: "cat")
            }
            .tag(AppTab.breeds)

            NavigationStack {
                FavoritesView(store: favoritesStore)
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(AppTab.favorites)
        }
    }
}
