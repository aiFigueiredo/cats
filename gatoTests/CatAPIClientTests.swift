import Foundation
import XCTest
@testable import gato

@MainActor
final class CatAPIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockCatAPIURLProtocol.reset()
    }

    override func tearDown() {
        MockCatAPIURLProtocol.reset()
        super.tearDown()
    }

    func testFetchBreedImageReturnsURLWhenResponseMatchesRequestedBreed() async throws {
        let expectedURL = URL(string: "https://cdn.example.com/abys.jpg")!

        MockCatAPIURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")

            let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            let queryItems = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(queryItems["breed_ids"], "abys")
            XCTAssertEqual(queryItems["limit"], "1")
            XCTAssertEqual(queryItems["has_breeds"], "1")
            XCTAssertEqual(queryItems["include_breeds"], "1")

            let payload = """
            [
              {
                "url": "\(expectedURL.absoluteString)",
                "breeds": [
                  { "id": "abys" }
                ]
              }
            ]
            """

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(payload.utf8))
        }

        let client = CatAPIClient.live(
            session: makeSession(),
            configuration: CatAPIConfiguration(
                baseURL: URL(string: "https://api.example.com")!,
                apiKey: "test-key"
            )
        )

        let imageURL = try await client.fetchBreedImage("abys")
        XCTAssertEqual(imageURL, expectedURL)
    }

    func testFetchBreedImageReturnsNilWhenResponseBreedDoesNotMatchRequestedBreed() async throws {
        let mismatchedURL = URL(string: "https://cdn.example.com/birm.jpg")!

        MockCatAPIURLProtocol.handler = { request in
            let payload = """
            [
              {
                "url": "\(mismatchedURL.absoluteString)",
                "breeds": [
                  { "id": "birm" }
                ]
              }
            ]
            """

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(payload.utf8))
        }

        let client = CatAPIClient.live(
            session: makeSession(),
            configuration: CatAPIConfiguration(
                baseURL: URL(string: "https://api.example.com")!,
                apiKey: nil
            )
        )

        let imageURL = try await client.fetchBreedImage("abys")
        XCTAssertNil(imageURL)
    }

    func testFetchBreedImageFallsBackToURLWhenBreedMetadataIsMissing() async throws {
        let expectedURL = URL(string: "https://cdn.example.com/no-breed-metadata.jpg")!

        MockCatAPIURLProtocol.handler = { request in
            let payload = """
            [
              {
                "url": "\(expectedURL.absoluteString)"
              }
            ]
            """

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(payload.utf8))
        }

        let client = CatAPIClient.live(
            session: makeSession(),
            configuration: CatAPIConfiguration(
                baseURL: URL(string: "https://api.example.com")!,
                apiKey: nil
            )
        )

        let imageURL = try await client.fetchBreedImage("abys")
        XCTAssertEqual(imageURL, expectedURL)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockCatAPIURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockCatAPIURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = MockCatAPIURLProtocol.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
