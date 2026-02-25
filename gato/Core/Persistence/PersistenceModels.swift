import CoreData
import Foundation

@objc(CDBreed)
final class CDBreed: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var origin: String?
    @NSManaged var temperament: String?
    @NSManaged var breedDescription: String?
    @NSManaged var lifeSpanMin: NSNumber?
    @NSManaged var lifeSpanMax: NSNumber?
    @NSManaged var imageURL: String?
    @NSManaged var lastUpdatedAt: Date
}

extension CDBreed {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDBreed> {
        NSFetchRequest<CDBreed>(entityName: "CDBreed")
    }
}

@objc(CDFavorite)
final class CDFavorite: NSManagedObject {
    @NSManaged var breedID: String
    @NSManaged var createdAt: Date
}

extension CDFavorite {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDFavorite> {
        NSFetchRequest<CDFavorite>(entityName: "CDFavorite")
    }
}

struct PersistenceStore {
    let container: NSPersistentContainer

    static func live() -> PersistenceStore {
        let model = makeManagedObjectModel()
        let container = NSPersistentContainer(name: "GatoStore", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Failed loading persistent store: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return PersistenceStore(container: container)
    }

    static func inMemory() -> PersistenceStore {
        let model = makeManagedObjectModel()
        let container = NSPersistentContainer(name: "GatoStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Failed loading in-memory store: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return PersistenceStore(container: container)
    }
}

private func makeManagedObjectModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()

    let breedEntity = NSEntityDescription()
    breedEntity.name = "CDBreed"
    breedEntity.managedObjectClassName = NSStringFromClass(CDBreed.self)

    let favoriteEntity = NSEntityDescription()
    favoriteEntity.name = "CDFavorite"
    favoriteEntity.managedObjectClassName = NSStringFromClass(CDFavorite.self)

    breedEntity.properties = [
        attribute(name: "id", type: .stringAttributeType, optional: false),
        attribute(name: "name", type: .stringAttributeType, optional: false),
        attribute(name: "origin", type: .stringAttributeType, optional: true),
        attribute(name: "temperament", type: .stringAttributeType, optional: true),
        attribute(name: "breedDescription", type: .stringAttributeType, optional: true),
        attribute(name: "lifeSpanMin", type: .integer32AttributeType, optional: true),
        attribute(name: "lifeSpanMax", type: .integer32AttributeType, optional: true),
        attribute(name: "imageURL", type: .stringAttributeType, optional: true),
        attribute(name: "lastUpdatedAt", type: .dateAttributeType, optional: false)
    ]

    favoriteEntity.properties = [
        attribute(name: "breedID", type: .stringAttributeType, optional: false),
        attribute(name: "createdAt", type: .dateAttributeType, optional: false)
    ]

    let breedIDIndex = NSFetchIndexDescription(
        name: "breed_id_index",
        elements: [NSFetchIndexElementDescription(property: breedEntity.properties[0], collationType: .binary)]
    )
    breedEntity.indexes = [breedIDIndex]
    breedEntity.uniquenessConstraints = [["id"]]

    let favoriteIDIndex = NSFetchIndexDescription(
        name: "favorite_id_index",
        elements: [NSFetchIndexElementDescription(property: favoriteEntity.properties[0], collationType: .binary)]
    )
    favoriteEntity.indexes = [favoriteIDIndex]
    favoriteEntity.uniquenessConstraints = [["breedID"]]

    model.entities = [breedEntity, favoriteEntity]
    return model
}

private func attribute(name: String, type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
    let attribute = NSAttributeDescription()
    attribute.name = name
    attribute.attributeType = type
    attribute.isOptional = optional
    return attribute
}
