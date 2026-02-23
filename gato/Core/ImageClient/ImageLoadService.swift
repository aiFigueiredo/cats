import Foundation
import UIKit

enum ImageLoadServiceError: Error, Equatable {
    case invalidResponse
    case decodeFailed
}

actor ImageLoadService {
    private let session: URLSession
    private let memoryCache = NSCache<NSURL, UIImage>()

    private var inFlightTasks: [URL: Task<UIImage, Error>] = [:]
    private var subscribersByURL: [URL: Set<UUID>] = [:]
    private var subscriptionToURL: [UUID: URL] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func subscribe(_ url: URL) -> UUID {
        let subscriptionID = UUID()
        subscribersByURL[url, default: []].insert(subscriptionID)
        subscriptionToURL[subscriptionID] = url
        return subscriptionID
    }

    func loadImage(for url: URL) async throws -> UIImage {
        if let cachedImage = memoryCache.object(forKey: url as NSURL) {
            return cachedImage
        }

        if let task = inFlightTasks[url] {
            return try await task.value
        }

        let task = Task<UIImage, Error> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
                throw ImageLoadServiceError.invalidResponse
            }
            guard let image = UIImage(data: data) else {
                throw ImageLoadServiceError.decodeFailed
            }
            return image
        }

        inFlightTasks[url] = task

        do {
            let image = try await task.value
            memoryCache.setObject(image, forKey: url as NSURL)
            inFlightTasks.removeValue(forKey: url)
            cleanupSubscriptionsIfNeeded(for: url)
            return image
        } catch {
            inFlightTasks.removeValue(forKey: url)
            cleanupSubscriptionsIfNeeded(for: url)
            throw error
        }
    }

    func cancel(_ subscriptionID: UUID, for url: URL) {
        let resolvedURL = subscriptionToURL.removeValue(forKey: subscriptionID) ?? url

        guard var subscribers = subscribersByURL[resolvedURL] else { return }
        subscribers.remove(subscriptionID)

        if subscribers.isEmpty {
            subscribersByURL.removeValue(forKey: resolvedURL)
            inFlightTasks[resolvedURL]?.cancel()
            inFlightTasks.removeValue(forKey: resolvedURL)
        } else {
            subscribersByURL[resolvedURL] = subscribers
        }
    }

    private func cleanupSubscriptionsIfNeeded(for url: URL) {
        guard let subscribers = subscribersByURL[url], subscribers.isEmpty else { return }
        subscribersByURL.removeValue(forKey: url)
    }
}
