import SwiftUI

struct AppView: View {
    @ObservedObject var store: Store<AppFeature.State, AppFeature.Action>
    @ObservedObject var breedsStore: Store<BreedsFeature.State, BreedsFeature.Action>
    @ObservedObject var favoritesStore: Store<FavoritesFeature.State, FavoritesFeature.Action>
    let imageClient: ImageClient

    var body: some View {
        TabView(selection: Binding(
            get: { store.state.selectedTab },
            set: { handleTabSelection($0) }
        )) {
            NavigationStack {
                BreedsView(
                    store: breedsStore,
                    imageClient: imageClient,
                    selectedTab: store.state.selectedTab
                )
            }
            .tabItem {
                Label("Breeds", systemImage: "cat")
            }
            .tag(AppTab.breeds)

            NavigationStack {
                FavoritesView(store: favoritesStore, imageClient: imageClient)
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(AppTab.favorites)
        }
        .onChange(of: favoritesStore.state.favorites) { _, favorites in
            let favoriteIDs = Set(favorites.map(\.id))
            breedsStore.send(.favoriteFlagsRefreshed(favoriteIDs))
        }
    }

    private func handleTabSelection(_ tab: AppTab) {
        store.send(.selectTab(tab))

        switch tab {
        case .breeds:
            let favoriteIDs = Set(favoritesStore.state.favorites.map(\.id))
            breedsStore.send(.favoriteFlagsRefreshed(favoriteIDs))
            breedsStore.send(.onAppear)
        case .favorites:
            favoritesStore.send(.onAppear)
        }
    }
}
