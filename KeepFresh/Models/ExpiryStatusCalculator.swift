import Foundation

/// Pure, timezone/calendar-aware classifier for an item's expiry state.
/// Never instantiate UI or persistence types here — this must stay a plain
/// function of (expiryDate, referenceDate, calendar, timeZone) so it's
/// trivially unit-testable and safely reusable from ViewModels, sorting,
/// and search, per the product spec's "single central calculator, never
/// duplicate these rules in individual views" rule.
enum ExpiryStatusCalculator {

    /// Items with this many days or fewer until expiry (inclusive) count as
    /// "expiring soon" — the spec's fixed 7-day threshold. (Whether this
    /// becomes user-configurable is still an open decision — see
    /// implementation-plan.md §11.)
    static let expiringSoonThresholdDays = 7

    static func status(
        for expiryDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> ExpiryStatus {
        switch daysUntilExpiry(from: expiryDate, referenceDate: referenceDate, calendar: calendar, timeZone: timeZone) {
        case ..<0:
            return .expired
        case 0...expiringSoonThresholdDays:
            return .expiringSoon
        default:
            return .good
        }
    }

    /// Whole calendar days between the start of `referenceDate`'s day and
    /// the start of `expiryDate`'s day, evaluated in `timeZone`. Negative
    /// means the expiry date has already passed. Always compares
    /// *start-of-day* to start-of-day — per the spec, expiry dates are
    /// date-only values, so a 23:59 reference time must not count as "one
    /// day earlier" than a bare expiry date.
    static func daysUntilExpiry(
        from expiryDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Int {
        var calendar = calendar
        calendar.timeZone = timeZone
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        let startOfReference = calendar.startOfDay(for: referenceDate)
        return calendar.dateComponents([.day], from: startOfReference, to: startOfExpiry).day ?? 0
    }

    /// Friendly copy per the spec: "Expires today", "Expires tomorrow",
    /// "Expires in 4 days", "Expired 2 days ago".
    static func displayText(
        for expiryDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let days = daysUntilExpiry(from: expiryDate, referenceDate: referenceDate, calendar: calendar, timeZone: timeZone)
        switch days {
        case 0:
            return "Expires today"
        case 1:
            return "Expires tomorrow"
        case let d where d > 1:
            return "Expires in \(d) days"
        case -1:
            return "Expired yesterday"
        default:
            return "Expired \(-days) days ago"
        }
    }
}
