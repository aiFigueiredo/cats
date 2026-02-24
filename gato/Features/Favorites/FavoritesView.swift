import ComposableArchitecture
import SwiftUI

struct FavoritesView: View {
    let store: StoreOf<FavoritesFeature>
    let imageClient: ImageClient

    var body: some View {
        Group {
            if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading favorites...")
                        .foregroundStyle(.secondary)
                }
            } else if let message = store.errorMessage, store.favorites.isEmpty {
                VStack(spacing: 12) {
                    Text("Could not load favorites")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if store.favorites.isEmpty {
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
                            Text(String(format: "%.1f years", averageLifeSpanMax))
                                .fontWeight(.semibold)
                        }
                        .accessibilityIdentifier("favorites_average_lifespan")
                    }

                    Section("Favorites") {
                        ForEach(store.favorites) { breed in
                            HStack(spacing: 12) {
                                NavigationLink {
                                    if let currentBreed = store.favorites.first(where: { $0.id == breed.id }) {
                                        BreedDetailView(
                                            state: BreedDetailFeature.State(
                                                breed: currentBreed,
                                                isFavoriteToggleInFlight: store.favoriteToggleInFlight.contains(breed.id)
                                            ),
                                            imageClient: imageClient,
                                            onToggleFavorite: {
                                                store.send(.toggleFavoriteTapped(breed.id))
                                            }
                                        )
                                    } else {
                                        Text("Breed unavailable")
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        RemoteImageView(url: breed.imageURL, imageClient: imageClient) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "cat.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .padding(10)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 48, height: 48)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Text(breed.name)

                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.send(.toggleFavoriteTapped(breed.id))
                                } label: {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless)
                                .disabled(store.favoriteToggleInFlight.contains(breed.id))
                                .accessibilityIdentifier("remove_favorite_\(breed.id)")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("favorites_list")
            }
        }
        .navigationTitle("Favorites")
    }

    private var averageLifeSpanMax: Double {
        let maxValues = store.favorites.compactMap { $0.lifeSpan?.max }
        guard !maxValues.isEmpty else { return 0 }
        let total = maxValues.reduce(0, +)
        return Double(total) / Double(maxValues.count)
    }
}
