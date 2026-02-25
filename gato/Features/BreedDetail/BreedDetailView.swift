import ComposableArchitecture
import SwiftUI

struct BreedDetailView: View {
    struct State: Equatable {
        var breed: Breed
        var isFavoriteToggleInFlight: Bool

        init(breed: Breed, isFavoriteToggleInFlight: Bool = false) {
            self.breed = breed
            self.isFavoriteToggleInFlight = isFavoriteToggleInFlight
        }
    }

    private let source: Source

    init(
        breedID: String,
        breedsStore: StoreOf<BreedsFeature>,
        imageClient: ImageClient
    ) {
        self.source = .breeds(
            breedID: breedID,
            breedsStore: breedsStore,
            imageClient: imageClient
        )
    }

    init(
        state: State,
        imageClient: ImageClient,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.source = .standalone(
            state: state,
            imageClient: imageClient,
            onToggleFavorite: onToggleFavorite
        )
    }

    @ViewBuilder
    var body: some View {
        switch source {
        case let .breeds(breedID, breedsStore, imageClient):
            if let breed = breedsStore.breedsByID[breedID] {
                detailContent(
                    state: State(
                        breed: breed,
                        isFavoriteToggleInFlight: breedsStore.favoriteToggleInFlight.contains(breedID)
                    ),
                    imageClient: imageClient,
                    onToggleFavorite: {
                        breedsStore.send(.toggleFavoriteTapped(breedID))
                    }
                )
            } else {
                Text("Breed unavailable")
                    .navigationTitle("Breed")
            }

        case let .standalone(state, imageClient, onToggleFavorite):
            detailContent(
                state: state,
                imageClient: imageClient,
                onToggleFavorite: onToggleFavorite
            )
        }
    }

    private func detailContent(
        state: State,
        imageClient: ImageClient,
        onToggleFavorite: @escaping () -> Void
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImageView(url: state.breed.imageURL, imageClient: imageClient) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "cat.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                breedDetailRow(title: "Origin", value: state.breed.origin ?? "Unknown")
                breedDetailRow(title: "Temperament", value: state.breed.temperament ?? "Unknown")
                breedDetailRow(title: "Description", value: state.breed.description ?? "No description available")
            }
            .padding()
        }
        .navigationTitle(state.breed.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: state.breed.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(state.breed.isFavorite ? "Remove \(state.breed.name) from favorites" : "Add \(state.breed.name) to favorites")
                .accessibilityIdentifier("favorite_\(state.breed.id)")
            }
        }
    }
}

private extension BreedDetailView {
    enum Source {
        case breeds(
            breedID: String,
            breedsStore: StoreOf<BreedsFeature>,
            imageClient: ImageClient
        )

        case standalone(
            state: State,
            imageClient: ImageClient,
            onToggleFavorite: () -> Void
        )
    }
}

private func breedDetailRow(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(value)
            .font(.body)
    }
}
