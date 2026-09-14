import Foundation
import UserNotifications

/// Pure identifier/fire-date derivation shared by the real and fake
/// notification services below, so "deterministic" doesn't mean
/// "implemented twice and hoped to stay in sync." Kept UIKit/UNUserNotification-
/// free in spirit (only Foundation types in its signatures) the same way
/// `ExpiryStatusCalculator` stays pure.
enum NotificationScheduling {
    /// `expiry.<itemUUID>.<expiryISODate>`, per implementation-plan.md §2 —
    /// stable for a given item+expiryDate pair, so replacing or cancelling
    /// a reminder is always deterministic rather than requiring the caller
    /// to remember what it scheduled last time.
    static func identifier(for item: Item) -> String {
        "expiry.\(item.id.uuidString).\(isoDateFormatter.string(from: item.expiryDate))"
    }

    /// `reminderDaysBefore` days before the (date-only) expiry date, at
    /// `hour`:00 local time — the spec's default reminder time (09:00).
    /// Returns nil if the arithmetic can't produce a date at all (should
    /// only happen with a pathological calendar); callers still need to
    /// separately check the result isn't already in the past.
    static func fireDate(for item: Item, calendar: Calendar = .current, hour: Int = 9) -> Date? {
        let startOfExpiry = calendar.startOfDay(for: item.expiryDate)
        guard let reminderDay = calendar.date(byAdding: .day, value: -item.reminderDaysBefore, to: startOfExpiry) else {
            return nil
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: reminderDay)
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Abstraction over local notification scheduling — the seam between
/// ItemEditorViewModel/ItemDetailsViewController and however reminders are
/// actually delivered, mirroring how `AuthServiceProtocol` and
/// `ItemRepository` already isolate their own concerns.
protocol NotificationServiceProtocol {
    /// Cancels whatever identifiers `item.notificationIdentifiers` already
    /// holds, then schedules a fresh reminder for its current
    /// expiryDate/reminderDaysBefore — unless that moment has already
    /// passed, per the spec's "do not schedule a past alert" rule, in
    /// which case nothing is scheduled. Returns the identifiers to persist
    /// on the item going forward (empty if nothing was scheduled). Covers
    /// both "new item" (nothing to cancel) and "edited item" (old
    /// identifiers cancelled first) with the same call.
    func reschedule(for item: Item) async -> [String]

    /// Cancels pending reminders for identifiers already known to be
    /// stale (e.g. the item was deleted). No-ops for an empty array.
    func cancel(identifiers: [String])
}

/// `UNUserNotificationCenter`-backed reminders — the real, shipping
/// implementation. Requests notification permission the first time it
/// actually has something to schedule (i.e. after the first item with a
/// future reminder is saved), per implementation-plan.md's "request
/// notification permission at a contextual point (after the first item is
/// saved is preferred)" — no separate call site needed elsewhere for that.
final class LocalNotificationService: NotificationServiceProtocol {

    private let center = UNUserNotificationCenter.current()
    private let calendar: Calendar
    private let notificationHour: Int

    init(calendar: Calendar = .current, notificationHour: Int = 9) {
        self.calendar = calendar
        self.notificationHour = notificationHour
    }

    func reschedule(for item: Item) async -> [String] {
        cancel(identifiers: item.notificationIdentifiers)

        guard let fireDate = NotificationScheduling.fireDate(for: item, calendar: calendar, hour: notificationHour),
              fireDate > Date()
        else {
            return []
        }

        await requestAuthorizationIfNeeded()

        let identifier = NotificationScheduling.identifier(for: item)
        let content = UNMutableNotificationContent()
        content.title = "\(item.name) is expiring soon"
        content.body = ExpiryStatusCalculator.displayText(for: item.expiryDate)
        content.sound = .default
        content.userInfo = ["itemID": item.id.uuidString]

        var triggerCalendar = calendar
        triggerCalendar.timeZone = .current
        let components = triggerCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return [identifier]
        } catch {
            // Scheduling failure isn't fatal to saving the item itself —
            // it just won't have a working reminder, matching the spec's
            // "notifications must remain useful even if permission is
            // declined" (Profile's Settings call-to-action is the other
            // half of that, not this service's job).
            return []
        }
    }

    func cancel(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}

/// In-memory fake for unit tests and previews — records what would have
/// been scheduled/cancelled without touching the real notification center
/// or ever prompting for permission, the same role `InMemoryItemRepository`
/// plays for persistence.
final class InMemoryNotificationService: NotificationServiceProtocol {
    private(set) var scheduledIdentifiers: Set<String> = []
    private(set) var rescheduleCallCount = 0

    func reschedule(for item: Item) async -> [String] {
        rescheduleCallCount += 1
        cancel(identifiers: item.notificationIdentifiers)

        guard let fireDate = NotificationScheduling.fireDate(for: item), fireDate > Date() else {
            return []
        }

        let identifier = NotificationScheduling.identifier(for: item)
        scheduledIdentifiers.insert(identifier)
        return [identifier]
    }

    func cancel(identifiers: [String]) {
        identifiers.forEach { scheduledIdentifiers.remove($0) }
    }
}
