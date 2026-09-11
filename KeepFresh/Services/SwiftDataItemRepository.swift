import Foundation
import SwiftData

/// SwiftData-backed `ItemRepository` — the "local-only v1" persistence the
/// Build Plan confirms (no Firestore/Storage until there's an actual
/// multi-device need). Owns every mapping between the domain-layer `Item`
/// struct and its on-disk `ItemEntity`.
///
/// `@MainActor`-bound rather than an `actor`: `ModelContext` itself is
/// main-actor-isolated in SwiftData, so fighting that with a custom actor
/// would just add a second layer of hopping for no benefit — call sites
/// (ViewModels) are already `@MainActor` themselves.
@MainActor
final class SwiftDataItemRepository: ItemRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() async throws -> [Item] {
        let descriptor = FetchDescriptor<ItemEntity>(
            sortBy: [SortDescriptor(\.expiryDate, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.asItem() }
    }

    func item(id: UUID) async throws -> Item? {
        try entity(id: id)?.asItem()
    }

    func save(_ item: Item) async throws {
        if let existing = try entity(id: item.id) {
            existing.update(from: item)
        } else {
            modelContext.insert(ItemEntity(item: item))
        }
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        guard let existing = try entity(id: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    private func entity(id: UUID) throws -> ItemEntity? {
        var descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
