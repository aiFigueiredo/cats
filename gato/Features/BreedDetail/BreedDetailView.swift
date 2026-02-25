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
            BreedDetailLiveSourceView(
                breedID: breedID,
                breedsStore: breedsStore,
                imageClient: imageClient
            )

        case let .standalone(state, imageClient, onToggleFavorite):
            BreedDetailContainerView(
                sourceState: state,
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

private struct BreedDetailLiveSourceView: View {
    let breedID: String
    let breedsStore: StoreOf<BreedsFeature>
    let imageClient: ImageClient

    var body: some View {
        Group {
            if let breed = breedsStore.breedsByID[breedID] {
                BreedDetailContainerView(
                    sourceState: BreedDetailFeature.State(
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

private struct BreedDetailContainerView: View {
    let sourceState: BreedDetailFeature.State
    let imageClient: ImageClient
    let onToggleFavorite: () -> Void

    @State private var store: StoreOf<BreedDetailFeature>

    init(
        sourceState: BreedDetailFeature.State,
        imageClient: ImageClient,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.sourceState = sourceState
        self.imageClient = imageClient
        self.onToggleFavorite = onToggleFavorite
        _store = State(initialValue: Store(initialState: sourceState) {
            BreedDetailFeature()
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImageView(url: store.breed.imageURL, imageClient: imageClient) { image in
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

                Text(store.breed.name)
                    .font(.title.bold())

                breedDetailRow(title: "Origin", value: store.breed.origin ?? "Unknown")
                breedDetailRow(title: "Temperament", value: store.breed.temperament ?? "Unknown")
                breedDetailRow(title: "Description", value: store.breed.description ?? "No description available")

                Button {
                    store.send(.favoriteButtonTapped)
                    onToggleFavorite()
                } label: {
                    Text(store.breed.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isFavoriteToggleInFlight)
                .accessibilityIdentifier("detail_favorite_button")
            }
            .padding()
        }
        .task(id: sourceState) {
            store.send(.sourceUpdated(sourceState.breed, sourceState.isFavoriteToggleInFlight))
        }
        .navigationTitle(store.breed.name)
        .navigationBarTitleDisplayMode(.inline)
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
