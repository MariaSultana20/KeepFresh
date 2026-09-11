import Foundation

/// Abstraction over however items are actually persisted. Screens and
/// ViewModels depend only on this protocol — never on SwiftData (or any
/// other storage API) directly — so the storage layer can change without
/// touching a view controller. `SwiftDataItemRepository` is the v1 (local-
/// only) implementation; an optional Firestore-backed one could sit behind
/// this same protocol later per the Build Plan, exactly like
/// `AuthServiceProtocol` already isolates auth from its implementation.
///
/// Deliberately a plain async CRUD surface, not a Combine/reactive one —
/// callers that need to observe changes (Home's live counts, Items' list)
/// can layer that on top once those screens actually exist; no need to
/// speculate on that shape now.
protocol ItemRepository {
    /// All items, sorted by expiry date ascending — the ordering every
    /// screen in the spec (Home's "Expiring Soon", the Items list) needs,
    /// so it belongs here once rather than being re-sorted at every call site.
    func fetchAll() async throws -> [Item]

    /// A single item by id, or nil if it doesn't exist (e.g. it was deleted
    /// elsewhere — callers like Item Details must handle this gracefully,
    /// not force-unwrap).
    func item(id: UUID) async throws -> Item?

    /// Creates the item if its id is new, otherwise updates the existing
    /// record in place — callers never need to know which case applies.
    func save(_ item: Item) async throws

    /// No-ops if the id doesn't exist rather than throwing — deleting
    /// something that's already gone is not an error condition for a caller.
    func delete(id: UUID) async throws
}
