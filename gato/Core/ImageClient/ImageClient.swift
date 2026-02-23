import Foundation

struct ImageClient {
    var service: ImageLoadService
}

extension ImageClient {
    static var live: ImageClient {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        configuration.timeoutIntervalForRequest = 30

        let session = URLSession(configuration: configuration)
        return ImageClient(service: ImageLoadService(session: session))
    }
}
