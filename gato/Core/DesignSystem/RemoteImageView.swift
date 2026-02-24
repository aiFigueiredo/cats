import SwiftUI
import UIKit

struct RemoteImageView<Content: View, Placeholder: View>: View {
    let url: URL?
    let imageClient: ImageClient
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var activeURL: URL?
    @State private var subscriptionID: UUID?
    @State private var loadTask: Task<Void, Never>?

    init(
        url: URL?,
        imageClient: ImageClient,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.imageClient = imageClient
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            cancelLoading()
            image = nil
            startLoading(for: url)
        }
        .onDisappear {
            cancelLoading()
        }
    }

    private func startLoading(for url: URL?) {
        guard let url else {
            activeURL = nil
            image = nil
            return
        }

        guard loadTask == nil else { return }
        activeURL = url

        loadTask = Task {
            let subscriptionID = await imageClient.service.subscribe(url)
            if Task.isCancelled {
                await imageClient.service.cancel(subscriptionID, for: url)
                return
            }
            await MainActor.run {
                self.subscriptionID = subscriptionID
            }

            do {
                let loaded = try await imageClient.service.loadImage(for: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if self.activeURL == url {
                        self.image = loaded
                    }
                }
            } catch {
                // Keep placeholder on error.
            }

            await MainActor.run {
                self.loadTask = nil
            }
        }
    }

    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil

        guard let activeURL, let subscriptionID else {
            self.activeURL = nil
            self.subscriptionID = nil
            return
        }

        self.activeURL = nil
        self.subscriptionID = nil
        Task {
            await imageClient.service.cancel(subscriptionID, for: activeURL)
        }
    }
}
