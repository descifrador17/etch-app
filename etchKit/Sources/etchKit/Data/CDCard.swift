import CoreData

/// Core Data row for a single flashcard, including its spaced-repetition state.
@objc(CDCard)
final class CDCard: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var question: String
    @NSManaged var answer: String
    @NSManaged var orderIndex: Int32
    @NSManaged var createdAt: Date

    // Spaced-repetition state
    @NSManaged var easeFactor: Double
    @NSManaged var intervalDays: Double
    @NSManaged var repetitions: Int32
    @NSManaged var dueDate: Date
    @NSManaged var lastReviewedAt: Date?

    @NSManaged var deck: CDDeck?
}

extension CDCard {
    static func fetchRequest() -> NSFetchRequest<CDCard> {
        NSFetchRequest<CDCard>(entityName: "CDCard")
    }
}
