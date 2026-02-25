import ComposableArchitecture
import SwiftUI

struct BreedsView: View {
    let store: StoreOf<BreedsFeature>
    let imageClient: ImageClient

    var body: some View {
        Group {
            if store.isLoading && store.visibleBreedIDs.isEmpty {
                loadingView
            } else if store.showFatalOfflineState {
                fatalOfflineView
            } else if let errorMessage = store.errorMessage, store.visibleBreedIDs.isEmpty {
                errorView(message: errorMessage)
            } else if store.visibleBreedIDs.isEmpty {
                emptyView
            } else {
                gridView
            }
        }
        .navigationTitle("Cats App")
        .searchable(
            text: Binding(
                get: { store.searchQuery },
                set: { store.send(.searchQueryChanged($0)) }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search cats"
        )
        .overlay(alignment: .top) {
            if let banner = store.bannerMessage {
                Text(banner)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 8)
                    .accessibilityIdentifier("cats_error_banner")
                    .onTapGesture {
                        store.send(.dismissBanner)
                    }
            }
        }
    }

    private var gridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.isOfflineMode {
                    Text("Offline mode: showing cached data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline_banner")
                }

                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(store.visibleBreedIDs, id: \.self) { breedID in
                        if let breed = store.breedsByID[breedID] {
                            VStack(spacing: 8) {
                                NavigationLink(value: BreedsRoute.breedDetail(breed.id)) {
                                    BreedGridTileContent(
                                        breed: breed,
                                        imageClient: imageClient,
                                        onFavorite: {
                                            store.send(.toggleFavoriteTapped(breed.id))
                                        }
                                    )
                                    .equatable()
                                }
                                .buttonStyle(.plain)
                            }
                            .onAppear {
                                if breed.imageURL == nil {
                                    store.send(.breedRowAppeared(breed.id))
                                }
                                if store.canLoadMore, breed.id == store.visibleBreedIDs.last {
                                    store.send(.loadNextPage)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityIdentifier("cats_list")
    }

    private var gridColumns: [GridItem] {
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading cats...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text("Could not load cats")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                store.send(.retryTapped)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("retry_button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Text("No cats available")
                .font(.headline)
            Text("Pull to refresh or try again later.")
                .foregroundStyle(.secondary)
            Button("Retry") {
                store.send(.retryTapped)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fatalOfflineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("You are offline")
                .font(.headline)
            Text("No cached cats are available yet. Connect to the internet and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                store.send(.retryTapped)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("retry_button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
