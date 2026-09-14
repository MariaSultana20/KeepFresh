import XCTest
@testable import KeepFresh

/// Exercises `ItemEditorViewModel`'s validation rules and its Add-vs-Edit
/// save behavior — the same "UIKit-free means testable" pattern
/// `AuthViewModel` already benefits from. Per
/// `claude/KeepFresh-Add-Item-Review-and-Plan.md` item 6: lock this down
/// now, before Edit mode's UI wiring makes any regression here harder to
/// catch by eye than by a failing test.
@MainActor
final class ItemEditorViewModelTests: XCTestCase {

    private func expiryDate(daysFromNow: Int = 5) -> Date {
        Date().addingTimeInterval(TimeInterval(daysFromNow) * 86_400)
    }

    // MARK: - Validation

    func test_validate_emptyName_producesNameError() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "   ", category: "Dairy", quantityText: "1", expiryDate: expiryDate())
        XCTAssertNotNil(result.nameError)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_emptyCategory_producesCategoryError() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "Milk", category: "   ", quantityText: "1", expiryDate: expiryDate())
        XCTAssertNotNil(result.categoryError)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_zeroQuantity_producesQuantityError() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "Milk", category: "Dairy", quantityText: "0", expiryDate: expiryDate())
        XCTAssertNotNil(result.quantityError)
    }

    func test_validate_negativeQuantity_producesQuantityError() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "Milk", category: "Dairy", quantityText: "-2", expiryDate: expiryDate())
        XCTAssertNotNil(result.quantityError)
    }

    func test_validate_nonNumericQuantity_producesQuantityError() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "Milk", category: "Dairy", quantityText: "abc", expiryDate: expiryDate())
        XCTAssertNotNil(result.quantityError)
    }

    func test_validate_nilExpiryDate_producesExpiryDateError() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "Milk", category: "Dairy", quantityText: "1", expiryDate: nil)
        XCTAssertNotNil(result.expiryDateError)
    }

    func test_validate_allFieldsValid_isValid() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        let result = viewModel.validate(name: "Milk", category: "Dairy", quantityText: "1", expiryDate: expiryDate())
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Add mode

    func test_addMode_initialValues_areDefaults() {
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository())
        XCTAssertFalse(viewModel.isEditing)
        XCTAssertEqual(viewModel.navigationTitle, "Add Item")
        XCTAssertEqual(viewModel.saveButtonTitle, "Add Item")
        XCTAssertEqual(viewModel.initialName, "")
        XCTAssertEqual(viewModel.initialQuantity, 1)
        XCTAssertEqual(viewModel.initialUnit, .piece)
        XCTAssertEqual(viewModel.initialReminderDaysBefore, 7)
        // New items can't be backdated — there should be a floor.
        XCTAssertNotNil(viewModel.minimumExpiryDate)
    }

    func test_addMode_save_createsANewItemWithFreshIdentity() async throws {
        let repository = InMemoryItemRepository()
        let viewModel = ItemEditorViewModel(itemRepository: repository)

        let didSave = expectation(description: "onSaved")
        var savedItem: Item?
        viewModel.onSaved = { item in
            savedItem = item
            didSave.fulfill()
        }

        viewModel.save(
            name: "Milk", category: "Dairy", quantity: 2, unit: .liter,
            purchaseDate: Date(), expiryDate: expiryDate(), note: "   ", reminderDaysBefore: 3
        )

        await fulfillment(of: [didSave], timeout: 1)

        let saved = try XCTUnwrap(savedItem)
        XCTAssertEqual(saved.name, "Milk")
        XCTAssertEqual(saved.quantity, 2)
        XCTAssertEqual(saved.unit, .liter)
        XCTAssertNil(saved.note) // blank note trims to nil, not an empty string
        XCTAssertTrue(saved.notificationIdentifiers.isEmpty)

        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored, [saved])
    }

    // MARK: - Edit mode

    func test_editMode_initialValues_comeFromTheExistingItem() {
        let existing = Item(
            name: "Yogurt", category: "Dairy", quantity: 4, unit: .pack,
            purchaseDate: Date(), expiryDate: expiryDate(daysFromNow: -2), // already expired
            note: "Family size", reminderDaysBefore: 1
        )
        let viewModel = ItemEditorViewModel(itemRepository: InMemoryItemRepository(), existingItem: existing)

        XCTAssertTrue(viewModel.isEditing)
        XCTAssertEqual(viewModel.navigationTitle, "Edit Item")
        XCTAssertEqual(viewModel.saveButtonTitle, "Save Changes")
        XCTAssertEqual(viewModel.initialName, "Yogurt")
        XCTAssertEqual(viewModel.initialQuantity, 4)
        XCTAssertEqual(viewModel.initialUnit, .pack)
        XCTAssertEqual(viewModel.initialNote, "Family size")
        XCTAssertEqual(viewModel.initialReminderDaysBefore, 1)
        // Existing (possibly already-expired) records stay freely editable —
        // no "can't be in the past" floor on the expiry picker.
        XCTAssertNil(viewModel.minimumExpiryDate)
    }

    func test_editMode_save_preservesIdCreatedAtAndNotificationIdentifiers() async throws {
        let existing = Item(
            name: "Yogurt", category: "Dairy", expiryDate: expiryDate(),
            notificationIdentifiers: ["expiry.abc.2026-09-20"],
            createdAt: Date().addingTimeInterval(-86_400)
        )
        let repository = InMemoryItemRepository(seedItems: [existing])
        let viewModel = ItemEditorViewModel(itemRepository: repository, existingItem: existing)

        let didSave = expectation(description: "onSaved")
        var savedItem: Item?
        viewModel.onSaved = { item in
            savedItem = item
            didSave.fulfill()
        }

        viewModel.save(
            name: "Whole Milk Yogurt", category: "Dairy", quantity: 1, unit: .piece,
            purchaseDate: Date(), expiryDate: expiryDate(daysFromNow: 10), note: "", reminderDaysBefore: 7
        )

        await fulfillment(of: [didSave], timeout: 1)

        let saved = try XCTUnwrap(savedItem)
        XCTAssertEqual(saved.id, existing.id)
        XCTAssertEqual(saved.createdAt, existing.createdAt)
        XCTAssertEqual(saved.notificationIdentifiers, existing.notificationIdentifiers)
        XCTAssertEqual(saved.name, "Whole Milk Yogurt") // every other field is replaced

        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored.count, 1) // updates in place, doesn't duplicate
    }
}
