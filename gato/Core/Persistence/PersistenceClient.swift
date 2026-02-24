import CoreData
import OSLog
import Foundation

struct PersistenceClient {
    var loadBreeds: () throws -> [Breed]
    var upsertBreeds: (_ breeds: [Breed], _ now: Date) throws -> Void
    var updateBreedImage: (_ breedID: String, _ imageURL: URL?) throws -> Void
    var loadFavoriteIDs: () throws -> Set<String>
    var setFavorite: (_ breedID: String, _ isFavorite: Bool) throws -> Void
    var isFavorite: (_ breedID: String) throws -> Bool
}

enum PersistenceError: LocalizedError, Equatable {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let detail):
            return detail
        }
    }
}

extension PersistenceClient {
    static func live(context: NSManagedObjectContext) -> PersistenceClient {
        PersistenceClient(
            loadBreeds: {
                do {
                    let favoriteIDs = try loadFavorites(context: context)
                    return try context.performSync {
                        let request = CDBreed.fetchRequest()
                        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CDBreed.name), ascending: true)]
                        return try context.fetch(request).map { $0.toDomain(isFavorite: favoriteIDs.contains($0.id)) }
                    }
                } catch {
                    AppLogger.persistence.error("loadBreeds failed: \(error.localizedDescription, privacy: .public)")
                    throw PersistenceError.failed("Failed loading breeds: \(error.localizedDescription)")
                }
            },
            upsertBreeds: { breeds, now in
                do {
                    try context.performSync {
                        for breed in breeds {
                            let request = CDBreed.fetchRequest()
                            request.predicate = NSPredicate(format: "id == %@", breed.id)
                            request.fetchLimit = 1

                            let managed = try context.fetch(request).first ?? CDBreed(context: context)
                            managed.id = breed.id
                            managed.name = breed.name
                            managed.origin = breed.origin
                            managed.temperament = breed.temperament
                            managed.breedDescription = breed.description
                            managed.lifeSpanMin = breed.lifeSpan.map { NSNumber(value: $0.min) }
                            managed.lifeSpanMax = breed.lifeSpan.map { NSNumber(value: $0.max) }
                            if let imageURL = breed.imageURL?.absoluteString {
                                managed.imageURL = imageURL
                            }
                            managed.lastUpdatedAt = now
                        }

                        if context.hasChanges {
                            try context.save()
                        }
                    }
                } catch {
                    AppLogger.persistence.error("upsertBreeds failed: \(error.localizedDescription, privacy: .public)")
                    throw PersistenceError.failed("Failed storing breeds: \(error.localizedDescription)")
                }
            },
            updateBreedImage: { breedID, imageURL in
                do {
                    try context.performSync {
                        let request = CDBreed.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", breedID)
                        request.fetchLimit = 1

                        guard let managed = try context.fetch(request).first else {
                            return
                        }

                        managed.imageURL = imageURL?.absoluteString
                        managed.lastUpdatedAt = Date()

                        if context.hasChanges {
                            try context.save()
                        }
                    }
                } catch {
                    AppLogger.persistence.error("updateBreedImage failed for \(breedID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    throw PersistenceError.failed("Failed updating breed image: \(error.localizedDescription)")
                }
            },
            loadFavoriteIDs: {
                do {
                    return try loadFavorites(context: context)
                } catch {
                    AppLogger.persistence.error("loadFavoriteIDs failed: \(error.localizedDescription, privacy: .public)")
                    throw PersistenceError.failed("Failed loading favorites: \(error.localizedDescription)")
                }
            },
            setFavorite: { breedID, isFavorite in
                do {
                    try context.performSync {
                        let request = CDFavorite.fetchRequest()
                        request.predicate = NSPredicate(format: "breedID == %@", breedID)
                        request.fetchLimit = 1

                        let existing = try context.fetch(request).first

                        if isFavorite {
                            if existing == nil {
                                let favorite = CDFavorite(context: context)
                                favorite.breedID = breedID
                                favorite.createdAt = Date()
                            }
                        } else if let existing {
                            context.delete(existing)
                        }

                        if context.hasChanges {
                            try context.save()
                        }
                    }
                } catch {
                    AppLogger.persistence.error("setFavorite failed for \(breedID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    throw PersistenceError.failed("Failed updating favorite: \(error.localizedDescription)")
                }
            },
            isFavorite: { breedID in
                do {
                    return try context.performSync {
                        let request = CDFavorite.fetchRequest()
                        request.predicate = NSPredicate(format: "breedID == %@", breedID)
                        request.fetchLimit = 1
                        return try context.fetch(request).first != nil
                    }
                } catch {
                    AppLogger.persistence.error("isFavorite failed for \(breedID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    throw PersistenceError.failed("Failed checking favorite: \(error.localizedDescription)")
                }
            }
        )
    }
}

private func loadFavorites(context: NSManagedObjectContext) throws -> Set<String> {
    try context.performSync {
        let favorites = try context.fetch(CDFavorite.fetchRequest())
        return Set(favorites.map(\.breedID))
    }
}

private extension CDBreed {
    func toDomain(isFavorite: Bool) -> Breed {
        let min = lifeSpanMin?.intValue
        let max = lifeSpanMax?.intValue
        let lifeSpan = min.map { LifeSpanRange(min: $0, max: max ?? $0) }

        return Breed(
            id: id,
            name: name,
            origin: origin,
            temperament: temperament,
            description: breedDescription,
            lifeSpan: lifeSpan,
            imageURL: URL(string: imageURL ?? ""),
            isFavorite: isFavorite
        )
    }
}

private extension NSManagedObjectContext {
    func performSync<T>(_ body: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        performAndWait {
            result = Result(catching: body)
        }
        return try result.get()
    }
}
