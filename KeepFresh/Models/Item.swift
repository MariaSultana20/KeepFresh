import Foundation

/// A tracked packaged product — the domain-layer value type used throughout
/// the UI and ViewModels. Deliberately a plain struct, not a SwiftData
/// `@Model`: persistence (added in a later commit, via `ItemRepository`)
/// maps this to/from its own on-disk `ItemEntity` representation, so no
/// screen or test ever has to depend on SwiftData directly.
///
/// Field set matches the Build Plan's confirmed addition of `quantity`,
/// `unit`, and `purchaseDate` on top of the original data-model spec.
struct Item: Identifiable, Equatable, Codable {

    /// Measurement unit for `quantity`. A closed set (picker in the Item
    /// Editor) rather than free text, so status/search/sort logic never has
    /// to parse unit strings.
    enum Unit: String, Codable, CaseIterable, Identifiable {
        case piece = "pcs"
        case gram = "g"
        case kilogram = "kg"
        case milliliter = "mL"
        case liter = "L"
        case pack = "pack"
        case box = "box"

        var id: String { rawValue }
        var displayName: String { rawValue }
    }

    var id: UUID
    var name: String
    var category: String
    var quantity: Double
    var unit: Unit
    var purchaseDate: Date?
    var expiryDate: Date
    var note: String?
    var reminderDaysBefore: Int
    var notificationIdentifiers: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        quantity: Double = 1,
        unit: Unit = .piece,
        purchaseDate: Date? = nil,
        expiryDate: Date,
        note: String? = nil,
        reminderDaysBefore: Int = 7,
        notificationIdentifiers: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.note = note
        self.reminderDaysBefore = reminderDaysBefore
        self.notificationIdentifiers = notificationIdentifiers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convenience wrapper around `ExpiryStatusCalculator` — the calculator
    /// itself stays a free function (easier to unit test in isolation);
    /// this just saves call sites from importing/naming it separately.
    func status(
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> ExpiryStatus {
        ExpiryStatusCalculator.status(for: expiryDate, referenceDate: referenceDate, calendar: calendar, timeZone: timeZone)
    }
}
