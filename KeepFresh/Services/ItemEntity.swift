import Foundation
import SwiftData

/// On-disk SwiftData representation of an `Item`. Only
/// `SwiftDataItemRepository` should ever construct, query, or touch this
/// type — everything else in the app (ViewModels, view controllers, tests)
/// works with the plain `Item` struct so it stays independent of SwiftData.
///
/// `unit` is stored as its raw `String` rather than `Item.Unit` directly:
/// SwiftData can store a `Codable` enum property, but predicate support for
/// enum-typed properties has been inconsistent across SwiftData versions —
/// storing the raw value keeps `#Predicate` filters on other fields
/// unaffected by that and keeps the on-disk shape trivially stable if
/// `Item.Unit`'s cases ever change.
@Model
final class ItemEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var quantity: Double
    var unitRawValue: String
    var purchaseDate: Date?
    var expiryDate: Date
    var note: String?
    var reminderDaysBefore: Int
    var notificationIdentifiers: [String]
    var createdAt: Date
    var updatedAt: Date

    init(item: Item) {
        id = item.id
        name = item.name
        category = item.category
        quantity = item.quantity
        unitRawValue = item.unit.rawValue
        purchaseDate = item.purchaseDate
        expiryDate = item.expiryDate
        note = item.note
        reminderDaysBefore = item.reminderDaysBefore
        notificationIdentifiers = item.notificationIdentifiers
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }

    /// Applies every mutable field from `item` onto this existing entity —
    /// used for updates, so `id`/`createdAt` identity is preserved rather
    /// than replacing the row.
    func update(from item: Item) {
        name = item.name
        category = item.category
        quantity = item.quantity
        unitRawValue = item.unit.rawValue
        purchaseDate = item.purchaseDate
        expiryDate = item.expiryDate
        note = item.note
        reminderDaysBefore = item.reminderDaysBefore
        notificationIdentifiers = item.notificationIdentifiers
        updatedAt = item.updatedAt
    }

    func asItem() -> Item {
        Item(
            id: id,
            name: name,
            category: category,
            quantity: quantity,
            unit: Item.Unit(rawValue: unitRawValue) ?? .piece,
            purchaseDate: purchaseDate,
            expiryDate: expiryDate,
            note: note,
            reminderDaysBefore: reminderDaysBefore,
            notificationIdentifiers: notificationIdentifiers,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
