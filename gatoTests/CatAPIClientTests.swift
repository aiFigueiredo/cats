import Foundation
import Testing
@testable import gato

@Suite("CatAPIClient", .serialized)
@MainActor
struct CatAPIClientTests {
    @Test("fetchBreedImage returns URL when response matches requested breed")
    func fetchBreedImageReturnsURLWhenResponseMatchesRequestedBreed() async throws {
        MockCatAPIURLProtocol.reset()
        defer { MockCatAPIURLProtocol.reset() }

        let expectedURL = URL(string: "https://cdn.example.com/abys.jpg")!

        MockCatAPIURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")

            let components = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)
            let queryItems = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(queryItems["breed_ids"] == "abys")
            #expect(queryItems["limit"] == "1")
            #expect(queryItems["has_breeds"] == "1")
            #expect(queryItems["include_breeds"] == "1")

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
                url: try #require(request.url),
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
        #expect(imageURL == expectedURL)
    }

    @Test("fetchBreedImage returns nil when response breed does not match requested breed")
    func fetchBreedImageReturnsNilWhenResponseBreedDoesNotMatchRequestedBreed() async throws {
        MockCatAPIURLProtocol.reset()
        defer { MockCatAPIURLProtocol.reset() }

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
                url: try #require(request.url),
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
        #expect(imageURL == nil)
    }

    @Test("fetchBreedImage falls back to URL when breed metadata is missing")
    func fetchBreedImageFallsBackToURLWhenBreedMetadataIsMissing() async throws {
        MockCatAPIURLProtocol.reset()
        defer { MockCatAPIURLProtocol.reset() }

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
                url: try #require(request.url),
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
        #expect(imageURL == expectedURL)
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
