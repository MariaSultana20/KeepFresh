import UIKit

/// Maps an item's category to a generic SF Symbol — the "generic icon per
/// category" decision (not a user-uploaded photo): the mockup's own "Add
/// Manually" form never actually collects a photo either, so there's
/// nothing to capture, store, or display beyond this. Same shape as
/// `ExpiryStatus`'s `color`/`label` — a pure mapping from a domain value to
/// its UI representation, kept here rather than duplicated at each call
/// site (`ItemRowView`, `ItemDetailsViewController`).
///
/// Covers Item Editor's preset category list (see
/// `ItemEditorViewController.presetCategories`); anything else, including
/// a free-typed category, falls back to a generic box rather than showing
/// nothing. Matching is case/whitespace-insensitive so "Dairy " and
/// "dairy" resolve to the same icon even though the category field itself
/// doesn't normalize those yet (see the accompanying review's tech-debt
/// note on that).
enum CategoryIcon {
    static func symbolName(for category: String) -> String {
        switch normalized(category) {
        case "dairy": return "drop.fill"
        case "bakery": return "birthday.cake.fill"
        case "beverages": return "cup.and.saucer.fill"
        case "pantry": return "cabinet.fill"
        case "snacks": return "bag.fill"
        case "frozen": return "snowflake"
        case "cosmetics": return "sparkles"
        case "medicine": return "cross.case.fill"
        case "household": return "house.fill"
        default: return "shippingbox.fill"
        }
    }

    private static func normalized(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
