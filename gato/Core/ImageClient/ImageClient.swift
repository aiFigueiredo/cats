import Foundation

struct ImageClient {
    var request: (_ url: URL?) -> URLRequest?
}

extension ImageClient {
    static var live: ImageClient {
        ImageClient { url in
            guard let url else { return nil }
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30
            return request
        }
    }
}
