import SwiftUI

struct BreedDetailView: View {
    let state: BreedDetailFeature.State
    let onToggleFavorite: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: state.breed.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "cat.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(24)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(state.breed.name)
                    .font(.title.bold())

                detailRow(title: "Origin", value: state.breed.origin ?? "Unknown")
                detailRow(title: "Temperament", value: state.breed.temperament ?? "Unknown")
                detailRow(title: "Description", value: state.breed.description ?? "No description available")

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

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}
