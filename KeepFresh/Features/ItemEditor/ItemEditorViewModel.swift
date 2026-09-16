import Combine
import Foundation

/// Per-field validation result for the Item Editor form. Same shape/spirit
/// as `EmailFormValidation` on the auth screens — field-specific errors
/// shown inline under each field rather than one shared banner.
struct ItemFormValidation {
    var nameError: String?
    var categoryError: String?
    var quantityError: String?
    var expiryDateError: String?

    var isValid: Bool {
        nameError == nil && categoryError == nil && quantityError == nil && expiryDateError == nil
    }
}

/// Owns validation and persistence for the Item Editor. One shared view
/// model for both Add and Edit, per the Build Plan's "one shared view in
/// two modes" spec — pass `existingItem` for Edit, leave it nil for Add.
///
/// Deliberately UIKit-free, like `AuthViewModel` — no alerts, no haptics —
/// so it stays testable and the view controller only translates its
/// published state into UI.
@MainActor
final class ItemEditorViewModel {

    /// Nil for Add mode. For Edit mode, only this item's `id`, `createdAt`,
    /// and `notificationIdentifiers` survive into the saved record — every
    /// other field is replaced by whatever the form currently holds.
    private let existingItem: Item?
    private let itemRepository: ItemRepository
    private let notificationService: NotificationServiceProtocol

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Set by the coordinator; called once `save` succeeds.
    var onSaved: ((Item) -> Void)?
    /// Set by the coordinator; called when the user taps Cancel. Routing
    /// cancellation through here (rather than the view controller calling
    /// `dismiss` on itself directly) keeps the coordinator as the single
    /// place that owns presenting *and* dismissing this modal, matching
    /// `AddItemCoordinator`'s own doc comment.
    var onCancel: (() -> Void)?

    var isEditing: Bool { existingItem != nil }
    var navigationTitle: String { isEditing ? "Edit Item" : "Add Item" }
    var saveButtonTitle: String { isEditing ? "Save Changes" : "Add Item" }

    /// Initial field values to populate the form with — the existing item's
    /// values in Edit mode, sensible defaults in Add mode (today's date,
    /// 1 piece, the spec's default 7-day reminder).
    var initialName: String { existingItem?.name ?? "" }
    var initialCategory: String { existingItem?.category ?? "" }
    var initialQuantity: Double { existingItem?.quantity ?? 1 }
    var initialUnit: Item.Unit { existingItem?.unit ?? .piece }
    var initialPurchaseDate: Date { existingItem?.purchaseDate ?? Date() }
    var initialExpiryDate: Date { existingItem?.expiryDate ?? Date() }
    var initialNote: String { existingItem?.note ?? "" }
    var initialReminderDaysBefore: Int { existingItem?.reminderDaysBefore ?? 7 }

    /// New items can't be backdated into the past — existing (possibly
    /// already-expired) records keep whatever date they have and can be
    /// edited freely, per the spec: "New records cannot select past dates;
    /// existing expired records remain editable."
    var minimumExpiryDate: Date? {
        isEditing ? nil : Calendar.current.startOfDay(for: Date())
    }

    init(itemRepository: ItemRepository, notificationService: NotificationServiceProtocol, existingItem: Item? = nil) {
        self.itemRepository = itemRepository
        self.notificationService = notificationService
        self.existingItem = existingItem
    }

    func validate(name: String, category: String, quantityText: String, expiryDate: Date?) -> ItemFormValidation {
        var result = ItemFormValidation()

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.nameError = "Enter a name."
        }
        if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.categoryError = "Choose or enter a category."
        }
        if let quantity = Double(quantityText), quantity > 0 {
            // valid
        } else {
            result.quantityError = "Enter a quantity greater than 0."
        }
        if expiryDate == nil {
            result.expiryDateError = "Choose an expiry date."
        }

        return result
    }

    /// Builds the record from the form's current values and persists it.
    /// Callers are expected to have already validated the form — this
    /// doesn't re-validate, it trusts its inputs and just saves them.
    func save(
        name: String,
        category: String,
        quantity: Double,
        unit: Item.Unit,
        purchaseDate: Date,
        expiryDate: Date,
        note: String,
        reminderDaysBefore: Int
    ) {
        errorMessage = nil
        isLoading = true

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var item = Item(
            id: existingItem?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            unit: unit,
            purchaseDate: purchaseDate,
            expiryDate: expiryDate,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            reminderDaysBefore: reminderDaysBefore,
            // Starting point for notificationService.reschedule(for:) below —
            // it reads this as "what to cancel first," then the return
            // value (fresh identifiers, or none if the reminder would
            // already be in the past) replaces it before the single save.
            notificationIdentifiers: existingItem?.notificationIdentifiers ?? [],
            createdAt: existingItem?.createdAt ?? Date(),
            updatedAt: Date()
        )

        Task {
            defer { isLoading = false }
            item.notificationIdentifiers = await notificationService.reschedule(for: item)
            do {
                try await itemRepository.save(item)
                onSaved?(item)
            } catch {
                // ItemRepository's errors are whatever SwiftData/the fetch
                // layer throws (there's no ItemRepositoryError case today,
                // unlike AuthError) — surface localizedDescription rather
                // than silently failing, and leave a note for a future pass
                // to give this a friendlier, typed error surface.
                errorMessage = "Couldn't save this item: \(error.localizedDescription)"
            }
        }
    }
}
