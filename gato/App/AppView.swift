import ComposableArchitecture
import SwiftUI

enum BreedsRoute: Hashable {
    case breedDetail(String)
}

enum FavoritesRoute: Hashable {
    case breedDetail(FavoritesDetailRoute)
}

struct FavoritesDetailRoute: Hashable {
    let breedID: String
    let breedSnapshot: Breed

    init(breed: Breed) {
        self.breedID = breed.id
        self.breedSnapshot = breed
    }

    static func == (lhs: FavoritesDetailRoute, rhs: FavoritesDetailRoute) -> Bool {
        lhs.breedID == rhs.breedID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(breedID)
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>
    let imageClient: ImageClient
    @State private var breedsPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            NavigationStack(path: $breedsPath) {
                BreedsView(
                    store: store.scope(state: \.breeds, action: \.breeds),
                    imageClient: imageClient
                )
                .navigationDestination(for: BreedsRoute.self, destination: breedsDestination)
            }
            .tabItem {
                Label("Cats List", systemImage: "cat")
            }
            .tag(AppTab.breeds)

            NavigationStack(path: $favoritesPath) {
                FavoritesView(
                    store: store.scope(state: \.favorites, action: \.favorites),
                    imageClient: imageClient
                )
                .navigationDestination(for: FavoritesRoute.self, destination: favoritesDestination)
            }
            .tabItem {
                Label("Favorites", systemImage: "star.fill")
            }
            .tag(AppTab.favorites)
        }
        .onAppear {
            store.send(.appStarted)
        }
    }

    private func breedsDestination(for route: BreedsRoute) -> some View {
        switch route {
        case let .breedDetail(breedID):
            return BreedDetailView(
                breedID: breedID,
                breedsStore: store.scope(state: \.breeds, action: \.breeds),
                imageClient: imageClient
            )
        }
    }

    private func favoritesDestination(for route: FavoritesRoute) -> some View {
        switch route {
        case let .breedDetail(detailRoute):
            let breedID = detailRoute.breedID
            let liveBreed = store.favorites.favorites.first(where: { $0.id == breedID })
            var breed = liveBreed ?? detailRoute.breedSnapshot
            if liveBreed == nil {
                breed.isFavorite = false
            }

            return BreedDetailView(
                state: BreedDetailView.State(
                    breed: breed,
                    isFavoriteToggleInFlight: store.favorites.favoriteToggleInFlight.contains(breedID)
                ),
                imageClient: imageClient,
                onToggleFavorite: {
                    guard store.favorites.favorites.contains(where: { $0.id == breedID }) else {
                        return
                    }
                    store.send(.favorites(.toggleFavoriteTapped(breedID)))
                }
            )
        }
    }
}
