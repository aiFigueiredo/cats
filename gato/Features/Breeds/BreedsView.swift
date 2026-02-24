import SwiftUI

struct BreedsView: View {
    @ObservedObject var store: Store<BreedsFeature.State, BreedsFeature.Action>
    let imageClient: ImageClient
    let selectedTab: AppTab

    var body: some View {
        Group {
            if store.state.isLoading && store.state.breeds.isEmpty {
                loadingView
            } else if store.state.showFatalOfflineState {
                fatalOfflineView
            } else if let errorMessage = store.state.errorMessage, store.state.breeds.isEmpty {
                errorView(message: errorMessage)
            } else if store.state.breeds.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .navigationTitle("Breeds")
        .searchable(
            text: Binding(
                get: { store.state.searchQuery },
                set: { store.send(.searchQueryChanged($0)) }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search breeds"
        )
        .overlay(alignment: .top) {
            if let banner = store.state.bannerMessage {
                Text(banner)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 8)
                    .accessibilityIdentifier("breeds_error_banner")
                    .onTapGesture {
                        store.send(.dismissBanner)
                    }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var listView: some View {
        List {
            if store.state.isOfflineMode {
                Text("Offline mode: showing cached data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("offline_banner")
            }

            ForEach(store.state.breeds) { breed in
                NavigationLink {
                    BreedDetailView(
                        breedID: breed.id,
                        breedsStore: store,
                        imageClient: imageClient,
                        selectedTab: selectedTab
                    )
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
                        .frame(width: 56, height: 56)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(breed.name)
                            .font(.body)

                        Spacer()

                        Button {
                            store.send(.toggleFavoriteTapped(breed.id))
                        } label: {
                            Image(systemName: breed.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(breed.isFavorite ? .red : .secondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(breed.isFavorite ? "Remove \(breed.name) from favorites" : "Add \(breed.name) to favorites")
                        .accessibilityIdentifier("favorite_\(breed.id)")
                        .disabled(store.state.favoriteToggleInFlight.contains(breed.id))
                    }
                }
                .contentShape(Rectangle())
                .onAppear {
                    store.send(.breedRowAppeared(breed.id))
                }
            }

            if store.state.isLoadingPage {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("breeds_list")
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading breeds...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text("Could not load breeds")
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
            Text("No breeds available")
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
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("You are offline")
                .font(.headline)
            Text("No cached breeds are available yet. Connect to the internet and try again.")
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
