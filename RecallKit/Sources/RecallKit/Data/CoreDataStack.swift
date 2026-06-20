import CoreData

/// Owns the `NSPersistentContainer`. The managed-object model is built in code
/// (rather than a binary `.xcdatamodeld`) so it loads identically from the app,
/// previews, and the package's in-memory test store — no momc, no bundle lookup.
/// Lightweight migration is enabled for when versioned models are introduced.
@MainActor
final class CoreDataStack {

    let container: NSPersistentContainer

    /// Shared on-disk stack for the running app.
    static let shared = CoreDataStack(inMemory: false)

    init(inMemory: Bool) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "Recall", managedObjectModel: model)

        let description = container.persistentStoreDescriptions.first!
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { _, error in
            if let error {
                // A failed local store is unrecoverable and indicates a programming
                // error (bad model). Crashing here is correct — there is no calm
                // degraded state for "cannot open the database".
                fatalError("Unresolved Core Data error: \(error)")
            }
        }

        let viewContext = container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    // MARK: - Programmatic model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Entities
        let deck = NSEntityDescription()
        deck.name = "CDDeck"
        deck.managedObjectClassName = NSStringFromClass(CDDeck.self)

        let card = NSEntityDescription()
        card.name = "CDCard"
        card.managedObjectClassName = NSStringFromClass(CDCard.self)

        // Deck attributes
        deck.properties = [
            attribute("id", .UUIDAttributeType, indexed: true),
            attribute("topic", .stringAttributeType),
            attribute("title", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("difficulty", .stringAttributeType, defaultValue: "medium"),
        ]

        // Card attributes
        card.properties = [
            attribute("id", .UUIDAttributeType, indexed: true),
            attribute("question", .stringAttributeType),
            attribute("answer", .stringAttributeType),
            attribute("orderIndex", .integer32AttributeType, defaultValue: 0),
            attribute("createdAt", .dateAttributeType),
            attribute("easeFactor", .doubleAttributeType, defaultValue: 2.5),
            attribute("intervalDays", .doubleAttributeType, defaultValue: 0),
            attribute("repetitions", .integer32AttributeType, defaultValue: 0),
            attribute("dueDate", .dateAttributeType),
            attribute("lastReviewedAt", .dateAttributeType, optional: true),
        ]

        // Relationships: CDDeck.cards <-->> CDCard.deck
        let cardsRel = NSRelationshipDescription()
        cardsRel.name = "cards"
        cardsRel.destinationEntity = card
        cardsRel.minCount = 0
        cardsRel.maxCount = 0                       // 0 == to-many
        cardsRel.deleteRule = .cascadeDeleteRule
        cardsRel.isOptional = true

        let deckRel = NSRelationshipDescription()
        deckRel.name = "deck"
        deckRel.destinationEntity = deck
        deckRel.minCount = 0
        deckRel.maxCount = 1
        deckRel.deleteRule = .nullifyDeleteRule
        deckRel.isOptional = true

        cardsRel.inverseRelationship = deckRel
        deckRel.inverseRelationship = cardsRel

        deck.properties.append(cardsRel)
        card.properties.append(deckRel)

        model.entities = [deck, card]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        indexed: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.isIndexed = indexed
        if let defaultValue {
            attribute.defaultValue = defaultValue
        }
        return attribute
    }
}
