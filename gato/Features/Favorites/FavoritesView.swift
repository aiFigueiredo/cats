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
                    Text("Star a breed from the Breeds tab to see it here.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Average lifespan")
                            Spacer()
                            Text(String(format: "%.1f years", averageLifeSpanMax))
                                .fontWeight(.semibold)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("favorites_average_lifespan")

                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(store.favorites) { breed in
                                VStack(spacing: 8) {
                                    NavigationLink {
                                        BreedDetailView(
                                            state: BreedDetailFeature.State(
                                                breed: breed,
                                                isFavoriteToggleInFlight: store.favoriteToggleInFlight.contains(breed.id)
                                            ),
                                            imageClient: imageClient,
                                            onToggleFavorite: {
                                                store.send(.toggleFavoriteTapped(breed.id))
                                            }
                                        )
                                    } label: {
                                        BreedGridTileContent(
                                            breed: breed,
                                            imageClient: imageClient,
                                            onFavorite: {
                                                store.send(.toggleFavoriteTapped(breed.id))
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .accessibilityIdentifier("favorites_list")
            }
        }
        .navigationTitle("Favorites")
    }

    private var gridColumns: [GridItem] {
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    private var averageLifeSpanMax: Double {
        let maxValues = store.favorites.compactMap { $0.lifeSpan?.max }
        guard !maxValues.isEmpty else { return 0 }
        let total = maxValues.reduce(0, +)
        return Double(total) / Double(maxValues.count)
    }
}
