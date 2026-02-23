import UIKit
import XCTest
@testable import gato

final class ImageLoadServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockImageURLProtocol.reset()
    }

    override func tearDown() {
        MockImageURLProtocol.reset()
        super.tearDown()
    }

    func testConcurrentLoadsForSameURLAreDeduplicated() async throws {
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

        XCTAssertEqual(MockImageURLProtocol.requestCount, 1)
    }

    func testCancelsDownloadWhenLastSubscriberCancels() async throws {
        let started = expectation(description: "request started")
        let stopped = expectation(description: "request cancelled by URLSession")
        let imageData = makeTestImageData()

        MockImageURLProtocol.onStopLoading = {
            stopped.fulfill()
        }
        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            started.fulfill()
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

        await fulfillment(of: [started], timeout: 1)
        await service.cancel(subscription, for: url)
        await fulfillment(of: [stopped], timeout: 1)

        do {
            _ = try await loadTask.value
            XCTFail("Expected image load to be canceled")
        } catch {
            let isCancellation = error is CancellationError || (error as NSError).code == NSURLErrorCancelled
            XCTAssertTrue(isCancellation)
        }
    }

    func testCancelOneSubscriberDoesNotCancelSharedRequest() async throws {
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
        XCTAssertEqual(MockImageURLProtocol.requestCount, 1)
    }

    func testSecondLoadUsesMemoryCache() async throws {
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

        XCTAssertEqual(MockImageURLProtocol.requestCount, 1)
    }

    func testDecodeFailureThrowsError() async throws {
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
            XCTFail("Expected decode failure")
        } catch let error as ImageLoadServiceError {
            XCTAssertEqual(error, .decodeFailed)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testNon2xxResponseThrowsInvalidResponse() async throws {
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
            XCTFail("Expected invalid response error")
        } catch let error as ImageLoadServiceError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testFailedLoadCanRetrySuccessfully() async throws {
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
            XCTFail("Expected first request to fail")
        } catch let error as ImageLoadServiceError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected first error \(error)")
        }

        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        _ = await service.subscribe(url)
        let retriedImage = try await service.loadImage(for: url)

        XCTAssertNotNil(retriedImage.pngData())
        XCTAssertEqual(MockImageURLProtocol.requestCount, 2)
    }

    func testCancelResolvesSubscriptionURLInsteadOfProvidedURL() async throws {
        let started = expectation(description: "request started")
        let stopped = expectation(description: "request cancelled via subscription map")
        let imageData = makeTestImageData()

        MockImageURLProtocol.onStopLoading = {
            stopped.fulfill()
        }
        MockImageURLProtocol.handler = { request in
            MockImageURLProtocol.requestCount += 1
            started.fulfill()
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

        await fulfillment(of: [started], timeout: 1)
        await service.cancel(subscription, for: wrongURL)
        await fulfillment(of: [stopped], timeout: 1)

        do {
            _ = try await loadTask.value
            XCTFail("Expected cancellation when using mismatched URL argument")
        } catch {
            let isCancellation = error is CancellationError || (error as NSError).code == NSURLErrorCancelled
            XCTAssertTrue(isCancellation)
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
}

private final class MockImageURLProtocol: URLProtocol {
    static var requestCount = 0
    static var handler: ((URLRequest) async throws -> (HTTPURLResponse, Data))?
    static var onStopLoading: (() -> Void)?

    private var loadingTask: Task<Void, Never>?

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
        loadingTask = Task { [request] in
            do {
                guard let handler = MockImageURLProtocol.handler else {
                    throw URLError(.badServerResponse)
                }
                let (response, data) = try await handler(request)
                if Task.isCancelled {
                    client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
                    return
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch is CancellationError {
                client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        MockImageURLProtocol.onStopLoading?()
    }
}
