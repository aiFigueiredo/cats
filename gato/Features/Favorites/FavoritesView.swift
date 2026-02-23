import SwiftUI

struct FavoritesView: View {
    @ObservedObject var store: Store<FavoritesFeature.State, FavoritesFeature.Action>

    var body: some View {
        Group {
            if store.state.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading favorites...")
                        .foregroundStyle(.secondary)
                }
            } else if let message = store.state.errorMessage, store.state.favorites.isEmpty {
                VStack(spacing: 12) {
                    Text("Could not load favorites")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if store.state.favorites.isEmpty {
                VStack(spacing: 12) {
                    Text("No favorites yet")
                        .font(.headline)
                    Text("Heart a breed from the Breeds tab to see it here.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    Section {
                        HStack {
                            Text("Average lifespan")
                            Spacer()
                            Text(String(format: "%.1f years", store.state.averageLifeSpanMax))
                                .fontWeight(.semibold)
                        }
                        .accessibilityIdentifier("favorites_average_lifespan")
                    }

                    Section("Favorites") {
                        ForEach(store.state.favorites) { breed in
                            NavigationLink {
                                if let currentBreed = store.state.favorites.first(where: { $0.id == breed.id }) {
                                    BreedDetailView(
                                        state: BreedDetailFeature.State(
                                            breed: currentBreed,
                                            isFavoriteToggleInFlight: store.state.favoriteToggleInFlight.contains(breed.id)
                                        ),
                                        onToggleFavorite: {
                                            store.send(.toggleFavoriteTapped(breed.id))
                                        }
                                    )
                                } else {
                                    Text("Breed unavailable")
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncImage(url: breed.imageURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            Image(systemName: "cat.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .padding(10)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 48, height: 48)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Text(breed.name)

                                    Spacer()

                                    Button {
                                        store.send(.toggleFavoriteTapped(breed.id))
                                    } label: {
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.state.favoriteToggleInFlight.contains(breed.id))
                                    .accessibilityIdentifier("remove_favorite_\(breed.id)")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("favorites_list")
            }
        }
        .navigationTitle("Favorites")
        .onAppear {
            store.send(.onAppear)
        }
    }
}
