import Testing
import UIKit
@testable import gato

@Suite("ImageLoadService", .serialized)
struct ImageLoadServiceTests {
    @Test("concurrent loads for same URL are deduplicated")
    func concurrentLoadsForSameURLAreDeduplicated() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        let imageData = makeTestImageData()
        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/cat.png")!

        _ = await service.subscribe(url)
        _ = await service.subscribe(url)

        async let first = service.loadImage(for: url)
        async let second = service.loadImage(for: url)
        _ = try await (first, second)

        #expect(MockImageURLProtocol.requestCount == 1)
    }

    @Test("cancels download when last subscriber cancels")
    func cancelsDownloadWhenLastSubscriberCancels() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        let started = LockedBox(false)
        let stopped = LockedBox(false)
        let imageData = makeTestImageData()

        MockImageURLProtocol.onStopLoading = {
            stopped.withValue { $0 = true }
        }
        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            started.withValue { $0 = true }
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try Task.checkCancellation()
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/slow.png")!
        let subscription = await service.subscribe(url)

        let loadTask = Task {
            try await service.loadImage(for: url)
        }

        #expect(await waitForFlag(started))
        await service.cancel(subscription, for: url)
        #expect(await waitForFlag(stopped))

        do {
            _ = try await loadTask.value
            Issue.record("Expected image load to be canceled")
        } catch {
            let isCancellation = error is CancellationError || (error as NSError).code == NSURLErrorCancelled
            #expect(isCancellation)
        }
    }

    @Test("cancel one subscriber does not cancel shared request")
    func cancelOneSubscriberDoesNotCancelSharedRequest() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        let imageData = makeTestImageData()

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            try await Task.sleep(nanoseconds: 200_000_000)
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/shared.png")!

        let firstSubscription = await service.subscribe(url)
        _ = await service.subscribe(url)

        async let first = service.loadImage(for: url)
        async let second = service.loadImage(for: url)
        await service.cancel(firstSubscription, for: url)

        _ = try await (first, second)
        #expect(MockImageURLProtocol.requestCount == 1)
    }

    @Test("second load uses memory cache")
    func secondLoadUsesMemoryCache() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        let imageData = makeTestImageData()

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/cache.png")!

        _ = await service.subscribe(url)
        _ = try await service.loadImage(for: url)
        _ = await service.subscribe(url)
        _ = try await service.loadImage(for: url)

        #expect(MockImageURLProtocol.requestCount == 1)
    }

    @Test("decode failure throws error")
    func decodeFailureThrowsError() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("not-an-image".utf8))
        }

        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/invalid.png")!

        _ = await service.subscribe(url)

        do {
            _ = try await service.loadImage(for: url)
            Issue.record("Expected decode failure")
        } catch let error as ImageLoadServiceError {
            #expect(error == .decodeFailed)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test("non 2xx response throws invalid response")
    func non2xxResponseThrowsInvalidResponse() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/server-error.png")!

        _ = await service.subscribe(url)

        do {
            _ = try await service.loadImage(for: url)
            Issue.record("Expected invalid response error")
        } catch let error as ImageLoadServiceError {
            #expect(error == .invalidResponse)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test("failed load can retry successfully")
    func failedLoadCanRetrySuccessfully() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        let imageData = makeTestImageData()
        let service = ImageLoadService(session: makeSession())
        let url = URL(string: "https://example.com/retry.png")!

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        _ = await service.subscribe(url)
        do {
            _ = try await service.loadImage(for: url)
            Issue.record("Expected first request to fail")
        } catch let error as ImageLoadServiceError {
            #expect(error == .invalidResponse)
        } catch {
            Issue.record("Unexpected first error \(error)")
        }

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        _ = await service.subscribe(url)
        let retriedImage = try await service.loadImage(for: url)

        #expect(retriedImage.pngData() != nil)
        #expect(MockImageURLProtocol.requestCount == 2)
    }

    @Test("cancel resolves subscription URL instead of provided URL")
    func cancelResolvesSubscriptionURLInsteadOfProvidedURL() async throws {
        MockImageURLProtocol.reset()
        defer { MockImageURLProtocol.reset() }

        let started = LockedBox(false)
        let stopped = LockedBox(false)
        let imageData = makeTestImageData()

        MockImageURLProtocol.onStopLoading = {
            stopped.withValue { $0 = true }
        }
        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            started.withValue { $0 = true }
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try Task.checkCancellation()
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let service = ImageLoadService(session: makeSession())
        let subscribedURL = URL(string: "https://example.com/subscribed.png")!
        let wrongURL = URL(string: "https://example.com/wrong.png")!
        let subscription = await service.subscribe(subscribedURL)

        let loadTask = Task {
            try await service.loadImage(for: subscribedURL)
        }

        #expect(await waitForFlag(started))
        await service.cancel(subscription, for: wrongURL)
        #expect(await waitForFlag(stopped))

        do {
            _ = try await loadTask.value
            Issue.record("Expected cancellation when using mismatched URL argument")
        } catch {
            let isCancellation = error is CancellationError || (error as NSError).code == NSURLErrorCancelled
            #expect(isCancellation)
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockImageURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeTestImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return image.pngData() ?? Data()
    }

    private func waitForFlag(_ flag: LockedBox<Bool>, timeoutNanoseconds: UInt64 = 1_000_000_000) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if flag.withValue({ $0 }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return flag.withValue { $0 }
    }
}

private final class MockImageURLProtocol: URLProtocol {
    static var requestCount = 0
    static var handler: ((URLRequest) async throws -> (HTTPURLResponse, Data))?
    static var onStopLoading: (() -> Void)?

    static func reset() {
        requestCount = 0
        handler = nil
        onStopLoading = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Task {
            do {
                guard let handler = MockImageURLProtocol.handler else {
                    throw URLError(.badServerResponse)
                }
                let (response, data) = try await handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        MockImageURLProtocol.onStopLoading?()
    }
}
