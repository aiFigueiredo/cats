import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>
    let imageClient: ImageClient

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            NavigationStack {
                BreedsView(
                    store: store.scope(state: \.breeds, action: \.breeds),
                    imageClient: imageClient,
                    selectedTab: store.selectedTab
                )
            }
            .tabItem {
                Label("Breeds", systemImage: "cat")
            }
            .tag(AppTab.breeds)

            NavigationStack {
                FavoritesView(
                    store: store.scope(state: \.favorites, action: \.favorites),
                    imageClient: imageClient
                )
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(AppTab.favorites)
        }
        .onAppear {
            store.send(.appStarted)
        }
    }
}
