import Foundation

/// In-memory `ItemRepository` for unit tests and previews — never used in
/// the shipping app. An `actor` (not a plain class) so concurrent
/// save/delete/fetch calls from tests can't race on the backing
/// dictionary; `SwiftDataItemRepository` gets the same safety for free from
/// `ModelContext`'s main-actor isolation, but a bare in-memory class here
/// would have had no such guarantee.
actor InMemoryItemRepository: ItemRepository {

    private var itemsByID: [UUID: Item]

    init(seedItems: [Item] = []) {
        itemsByID = Dictionary(uniqueKeysWithValues: seedItems.map { ($0.id, $0) })
    }

    func fetchAll() async throws -> [Item] {
        itemsByID.values.sorted { $0.expiryDate < $1.expiryDate }
    }

    func item(id: UUID) async throws -> Item? {
        itemsByID[id]
    }

    func save(_ item: Item) async throws {
        itemsByID[item.id] = item
    }

    func delete(id: UUID) async throws {
        itemsByID.removeValue(forKey: id)
    }
}
