import Foundation
import OSLog

struct CatAPIClient {
    var fetchBreeds: (_ page: Int, _ limit: Int) async throws -> [Breed]
    var fetchBreedImage: (_ breedID: String) async throws -> URL?
}

enum CatAPIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case rateLimited
    case offline
    case invalidResponse
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration."
        case .unauthorized:
            return "Unauthorized. Check your API key configuration."
        case .rateLimited:
            return "Rate-limited by The Cat API. Please try again later."
        case .offline:
            return "No internet connection."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .decoding(let detail):
            return "Failed to decode response: \(detail)"
        case .unknown(let detail):
            return detail
        }
    }
}

struct CatAPIConfiguration {
    var baseURL: URL
    var apiKey: String?

    static var live: CatAPIConfiguration {
        CatAPIConfiguration(
            baseURL: URL(string: "https://api.thecatapi.com")!,
            apiKey: ProcessInfo.processInfo.environment["CAT_API_KEY"] ?? (Bundle.main.object(forInfoDictionaryKey: "CAT_API_KEY") as? String)
        )
    }
}

extension CatAPIClient {
    static func live(
        session: URLSession = .shared,
        configuration: CatAPIConfiguration = .live,
        decoder: JSONDecoder = JSONDecoder()
    ) -> CatAPIClient {
        CatAPIClient(
            fetchBreeds: { page, limit in
                var components = URLComponents(url: configuration.baseURL.appending(path: "/v1/breeds"), resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "limit", value: String(limit))
                ]

                guard let url = components?.url else {
                    throw CatAPIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                if let apiKey = configuration.apiKey, !apiKey.isEmpty {
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                }

                do {
                    AppLogger.api.debug("Fetching breeds page=\(page) limit=\(limit)")
                    let (data, response) = try await session.data(for: request)
                    let httpResponse = try validate(response: response)

                    if httpResponse.statusCode == 204 {
                        return []
                    }

                    do {
                        let payload = try decoder.decode([BreedDTO].self, from: data)
                        return payload.map { $0.toDomain() }
                    } catch {
                        throw CatAPIError.decoding(error.localizedDescription)
                    }
                } catch {
                    throw mapError(error)
                }
            },
            fetchBreedImage: { breedID in
                var components = URLComponents(url: configuration.baseURL.appending(path: "/v1/images/search"), resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "breed_ids", value: breedID),
                    URLQueryItem(name: "limit", value: "1"),
                    URLQueryItem(name: "has_breeds", value: "1"),
                    URLQueryItem(name: "include_breeds", value: "1")
                ]

                guard let url = components?.url else {
                    throw CatAPIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                if let apiKey = configuration.apiKey, !apiKey.isEmpty {
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                }

                do {
                    AppLogger.api.debug("Fetching breed image id=\(breedID)")
                    let (data, response) = try await session.data(for: request)
                    _ = try validate(response: response)

                    do {
                        let payload = try decoder.decode([BreedImageDTO].self, from: data)
                        guard let first = payload.first else {
                            return nil
                        }

                        if let breeds = first.breeds, !breeds.isEmpty,
                           !breeds.contains(where: { $0.id == breedID }) {
                            AppLogger.api.warning("Ignoring mismatched image response for breed id=\(breedID, privacy: .public)")
                            return nil
                        }

                        return first.url
                    } catch {
                        throw CatAPIError.decoding(error.localizedDescription)
                    }
                } catch {
                    throw mapError(error)
                }
            }
        )
    }

    static func validate(response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return httpResponse
        case 401:
            throw CatAPIError.unauthorized
        case 429:
            throw CatAPIError.rateLimited
        default:
            throw CatAPIError.unknown("Unexpected status code: \(httpResponse.statusCode)")
        }
    }

    static func mapError(_ error: Error) -> CatAPIError {
        if let apiError = error as? CatAPIError {
            return apiError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut:
                return .offline
            default:
                return .unknown(urlError.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}

private struct BreedDTO: Decodable {
    struct ImageDTO: Decodable {
        let url: URL?
    }

    let id: String
    let name: String
    let origin: String?
    let temperament: String?
    let description: String?
    let lifeSpan: String?
    let image: ImageDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case origin
        case temperament
        case description
        case lifeSpan = "life_span"
        case image
    }

    func toDomain() -> Breed {
        Breed(
            id: id,
            name: name,
            origin: origin,
            temperament: temperament,
            description: description,
            lifeSpan: LifeSpanRange(rawValue: lifeSpan),
            imageURL: image?.url,
            isFavorite: false
        )
    }
}

private struct BreedImageDTO: Decodable {
    struct BreedReferenceDTO: Decodable {
        let id: String
    }

    let url: URL?
    let breeds: [BreedReferenceDTO]?
}
