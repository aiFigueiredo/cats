import ComposableArchitecture
import SwiftUI

struct BreedDetailView: View {
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
        state: BreedDetailFeature.State,
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
            BreedDetailContentView(
                breedID: breedID,
                breedsStore: breedsStore,
                imageClient: imageClient
            )

        case let .standalone(state, imageClient, onToggleFavorite):
            breedDetailBody(
                state: state,
                imageClient: imageClient,
                onToggleFavorite: onToggleFavorite
            )
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
            state: BreedDetailFeature.State,
            imageClient: ImageClient,
            onToggleFavorite: () -> Void
        )
    }
}

private struct BreedDetailContentView: View {
    let breedID: String
    let breedsStore: StoreOf<BreedsFeature>
    let imageClient: ImageClient

    var body: some View {
        Group {
            if let breed = breedsStore.breedsByID[breedID] {
                breedDetailBody(
                    state: BreedDetailFeature.State(
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
        }
    }
}

private func breedDetailBody(
    state: BreedDetailFeature.State,
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

            Text(state.breed.name)
                .font(.title.bold())

            breedDetailRow(title: "Origin", value: state.breed.origin ?? "Unknown")
            breedDetailRow(title: "Temperament", value: state.breed.temperament ?? "Unknown")
            breedDetailRow(title: "Description", value: state.breed.description ?? "No description available")

            Button {
                onToggleFavorite()
            } label: {
                Text(state.breed.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.isFavoriteToggleInFlight)
            .accessibilityIdentifier("detail_favorite_button")
        }
        .padding()
    }
    .navigationTitle(state.breed.name)
    .navigationBarTitleDisplayMode(.inline)
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
