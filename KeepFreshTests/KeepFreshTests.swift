import XCTest
@testable import KeepFresh

/// Smoke test proving the test target is wired correctly (host app builds,
/// `@testable import KeepFresh` resolves, and the test runner can execute
/// against it). Real coverage starts with `ExpiryStatusCalculatorTests`.
final class KeepFreshTests: XCTestCase {
    func test_testTargetIsWiredUp() {
        XCTAssertTrue(true)
    }
}
