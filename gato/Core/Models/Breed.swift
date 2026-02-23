import Foundation

struct Breed: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let origin: String?
    let temperament: String?
    let description: String?
    let lifeSpan: LifeSpanRange?
    var imageURL: URL?
    var isFavorite: Bool
}

struct LifeSpanRange: Equatable, Sendable {
    let min: Int
    let max: Int

    init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }

    init?(rawValue: String?) {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        let parts = rawValue
            .split(separator: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let first = parts.first, let min = Int(first) else { return nil }
        let max = Int(parts.last ?? first) ?? min

        self.min = min
        self.max = max
    }
}
