import XCTest
@testable import KeepFresh

/// Boundary coverage for `ExpiryStatusCalculator`, matching the acceptance
/// checklist in implementation-plan.md §9: yesterday (Expired), today
/// (Expiring Soon), +7 days (Expiring Soon), +8 days (Good), and a
/// daylight-saving transition.
final class ExpiryStatusCalculatorTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = utc
        return calendar.date(from: components)!
    }

    // MARK: - status(for:)

    func test_yesterday_isExpired() {
        let reference = date(2026, 1, 10)
        let status = ExpiryStatusCalculator.status(for: date(2026, 1, 9), referenceDate: reference, calendar: calendar, timeZone: utc)
        XCTAssertEqual(status, .expired)
    }

    func test_today_isExpiringSoon() {
        let reference = date(2026, 1, 10)
        let status = ExpiryStatusCalculator.status(for: reference, referenceDate: reference, calendar: calendar, timeZone: utc)
        XCTAssertEqual(status, .expiringSoon)
    }

    func test_sevenDaysAhead_isExpiringSoon() {
        let reference = date(2026, 1, 10)
        let status = ExpiryStatusCalculator.status(for: date(2026, 1, 17), referenceDate: reference, calendar: calendar, timeZone: utc)
        XCTAssertEqual(status, .expiringSoon)
    }

    func test_eightDaysAhead_isGood() {
        let reference = date(2026, 1, 10)
        let status = ExpiryStatusCalculator.status(for: date(2026, 1, 18), referenceDate: reference, calendar: calendar, timeZone: utc)
        XCTAssertEqual(status, .good)
    }

    /// A reference time late in the day must not "eat" a day — status is
    /// computed start-of-day to start-of-day, per the spec's "expiry dates
    /// are date-only values" rule.
    func test_lateReferenceTime_doesNotShiftTheBoundary() {
        let reference = date(2026, 1, 10, hour: 23)
        let status = ExpiryStatusCalculator.status(for: date(2026, 1, 17), referenceDate: reference, calendar: calendar, timeZone: utc)
        XCTAssertEqual(status, .expiringSoon)
    }

    // MARK: - Daylight saving transition

    /// US spring-forward 2026-03-08 in America/New_York (clocks jump 2am ->
    /// 3am, a 23-hour wall-clock day). The day-count must still read
    /// exactly 1, not be thrown off by the missing hour.
    func test_daylightSavingSpringForward_doesNotSkipADay() {
        var newYorkCalendar = Calendar(identifier: .gregorian)
        let newYork = TimeZone(identifier: "America/New_York")!
        newYorkCalendar.timeZone = newYork

        func newYorkDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 12
            components.timeZone = newYork
            return newYorkCalendar.date(from: components)!
        }

        let reference = newYorkDate(2026, 3, 7)
        let expiry = newYorkDate(2026, 3, 8)
        let days = ExpiryStatusCalculator.daysUntilExpiry(from: expiry, referenceDate: reference, calendar: newYorkCalendar, timeZone: newYork)
        XCTAssertEqual(days, 1)
    }

    // MARK: - displayText(for:)

    func test_displayText_today() {
        let reference = date(2026, 1, 10)
        XCTAssertEqual(
            ExpiryStatusCalculator.displayText(for: reference, referenceDate: reference, calendar: calendar, timeZone: utc),
            "Expires today"
        )
    }

    func test_displayText_tomorrow() {
        let reference = date(2026, 1, 10)
        XCTAssertEqual(
            ExpiryStatusCalculator.displayText(for: date(2026, 1, 11), referenceDate: reference, calendar: calendar, timeZone: utc),
            "Expires tomorrow"
        )
    }

    func test_displayText_futureDays() {
        let reference = date(2026, 1, 10)
        XCTAssertEqual(
            ExpiryStatusCalculator.displayText(for: date(2026, 1, 14), referenceDate: reference, calendar: calendar, timeZone: utc),
            "Expires in 4 days"
        )
    }

    func test_displayText_yesterday() {
        let reference = date(2026, 1, 10)
        XCTAssertEqual(
            ExpiryStatusCalculator.displayText(for: date(2026, 1, 9), referenceDate: reference, calendar: calendar, timeZone: utc),
            "Expired yesterday"
        )
    }

    func test_displayText_pastDays() {
        let reference = date(2026, 1, 10)
        XCTAssertEqual(
            ExpiryStatusCalculator.displayText(for: date(2026, 1, 8), referenceDate: reference, calendar: calendar, timeZone: utc),
            "Expired 2 days ago"
        )
    }
}
