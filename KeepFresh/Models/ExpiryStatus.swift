import UIKit

/// An item's freshness state, derived from its expiry date — never stored,
/// always computed (see `ExpiryStatusCalculator`, added in the next commit).
/// Screens render status through `color`/`label` here rather than
/// re-deriving the red/orange/green traffic-light system or its wording.
enum ExpiryStatus: String, Codable, CaseIterable {
    case expired
    case expiringSoon
    case good

    var color: UIColor {
        switch self {
        case .expired: return AppTheme.Color.expired
        case .expiringSoon: return AppTheme.Color.expiringSoon
        case .good: return AppTheme.Color.good
        }
    }

    var label: String {
        switch self {
        case .expired: return "Expired"
        case .expiringSoon: return "Expiring Soon"
        case .good: return "Good"
        }
    }
}
