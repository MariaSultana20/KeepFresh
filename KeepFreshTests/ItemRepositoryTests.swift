import XCTest
@testable import KeepFresh

/// Exercises `InMemoryItemRepository` against the `ItemRepository` contract
/// itself — every assertion here is really a statement about what any
/// conformer (including `SwiftDataItemRepository`) is expected to do, even
/// though only the in-memory fake is practical to unit test without a real
/// SwiftData store.
final class ItemRepositoryTests: XCTestCase {

    private func makeItem(name: String = "Milk", category: String = "Dairy", daysFromNow: Int) -> Item {
        Item(name: name, category: category, expiryDate: Date().addingTimeInterval(TimeInterval(daysFromNow) * 86_400))
    }

    func test_fetchAll_startsEmpty() async throws {
        let repository = InMemoryItemRepository()
        let items = try await repository.fetchAll()
        XCTAssertTrue(items.isEmpty)
    }

    func test_save_thenFetchAll_returnsTheSavedItem() async throws {
        let repository = InMemoryItemRepository()
        let item = makeItem(daysFromNow: 3)
        try await repository.save(item)
        let items = try await repository.fetchAll()
        XCTAssertEqual(items, [item])
    }

    func test_save_withAnExistingID_updatesInPlaceRatherThanDuplicating() async throws {
        let repository = InMemoryItemRepository()
        var item = makeItem(daysFromNow: 3)
        try await repository.save(item)

        item.name = "Whole Milk"
        try await repository.save(item)

        let items = try await repository.fetchAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Whole Milk")
    }

    func test_fetchAll_sortsByExpiryDateAscending() async throws {
        let repository = InMemoryItemRepository()
        let soon = makeItem(name: "Yogurt", daysFromNow: 1)
        let later = makeItem(name: "Cheese", daysFromNow: 10)

        // Saved out of order on purpose — the repository, not save-order,
        // must be what determines fetchAll's ordering.
        try await repository.save(later)
        try await repository.save(soon)

        let items = try await repository.fetchAll()
        XCTAssertEqual(items.map(\.name), ["Yogurt", "Cheese"])
    }

    func test_item_returnsTheMatchingItemByID() async throws {
        let repository = InMemoryItemRepository()
        let item = makeItem(daysFromNow: 3)
        try await repository.save(item)

        let fetched = try await repository.item(id: item.id)
        XCTAssertEqual(fetched, item)
    }

    func test_item_returnsNilForAnUnknownID() async throws {
        let repository = InMemoryItemRepository()
        let fetched = try await repository.item(id: UUID())
        XCTAssertNil(fetched)
    }

    func test_delete_removesTheItem() async throws {
        let repository = InMemoryItemRepository()
        let item = makeItem(daysFromNow: 3)
        try await repository.save(item)

        try await repository.delete(id: item.id)

        let items = try await repository.fetchAll()
        XCTAssertTrue(items.isEmpty)
    }

    func test_delete_withAnUnknownID_doesNotThrow() async throws {
        let repository = InMemoryItemRepository()
        try await repository.delete(id: UUID())
        // Reaching this line without throwing is the assertion — deleting
        // something that's already gone isn't an error, per the protocol's
        // documented contract.
    }

    func test_seedItems_areAvailableImmediately() async throws {
        let seed = makeItem(name: "Butter", daysFromNow: 5)
        let repository = InMemoryItemRepository(seedItems: [seed])
        let items = try await repository.fetchAll()
        XCTAssertEqual(items, [seed])
    }
}
