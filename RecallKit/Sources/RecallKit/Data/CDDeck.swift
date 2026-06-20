import CoreData

/// Core Data row for a deck. Manual codegen — this class and its model are
/// hand-authored so we control `Sendable` boundaries. Never leaves the repo.
@objc(CDDeck)
final class CDDeck: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var topic: String
    @NSManaged var title: String
    @NSManaged var createdAt: Date
    @NSManaged var cards: Set<CDCard>
}

extension CDDeck {
    static func fetchRequest() -> NSFetchRequest<CDDeck> {
        NSFetchRequest<CDDeck>(entityName: "CDDeck")
    }
}
