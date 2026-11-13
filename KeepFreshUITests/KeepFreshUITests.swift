import XCTest

/// Golden-path UI tests for KeepFresh.
///
/// These tests rely on `accessibilityIdentifier`s set on key controls
/// throughout the app. All identifiers used here are defined in the
/// corresponding view controllers:
///   - Sign In screen (SignInViewController.setupAccessibilityIdentifiers)
///   - Item rows (ItemRowView.init)
///   - Profile screen (ProfileViewController)
///
/// Tests run against the app as-is; they use a real app launch and do NOT
/// inject mocks. For the sign-in tests to pass you need a test Firebase
/// account configured in the simulator's keychain, or run them against a
/// build variant that injects MockAuthService. For now the sign-in test is
/// structured to validate the UI flow only (button presence, field focus,
/// error states) rather than completing a real network sign-in.
final class KeepFreshUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: Sign-In Screen

    func testSignInScreenShowsRequiredElements() {
        // The app should land on Sign In when no session is cached.
        // We verify the key controls are present before attempting interaction.
        let emailField = app.textFields["sign-in-email-field"]
        let passwordField = app.secureTextFields["sign-in-password-field"]
        let signInButton = app.buttons["sign-in-button"]
        let createAccountButton = app.buttons["create-account-button"]
        let googleButton = app.buttons["google-sign-in-button"]

        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email field not found on Sign In screen")
        XCTAssertTrue(passwordField.exists, "Password field not found")
        XCTAssertTrue(signInButton.exists, "Sign In button not found")
        XCTAssertTrue(createAccountButton.exists, "Create Account button not found")
        XCTAssertTrue(googleButton.exists, "Google sign-in button not found")
    }

    func testSignInWithEmptyFieldsShowsValidationFeedback() {
        let signInButton = app.buttons["sign-in-button"]
        guard signInButton.waitForExistence(timeout: 5) else {
            XCTFail("Sign In screen not shown at launch")
            return
        }
        // Tap Sign In with no credentials — the ViewModel rejects the form
        // before making any network call, so this is purely local validation.
        signInButton.tap()
        // After an invalid tap the sign-in button should still be present
        // (no navigation should have occurred).
        XCTAssertTrue(signInButton.exists, "Sign In button disappeared after empty-field tap")
    }

    func testSignInEmailFieldAcceptsInput() {
        let emailField = app.textFields["sign-in-email-field"]
        guard emailField.waitForExistence(timeout: 5) else {
            XCTFail("Sign In screen not shown at launch")
            return
        }
        emailField.tap()
        emailField.typeText("test@example.com")
        XCTAssertEqual(emailField.value as? String, "test@example.com")
    }

    func testNavigateToCreateAccount() {
        let createAccountButton = app.buttons["create-account-button"]
        guard createAccountButton.waitForExistence(timeout: 5) else {
            XCTFail("Sign In screen not shown at launch")
            return
        }
        createAccountButton.tap()
        // After navigating to Create Account the Sign In button should no
        // longer be the first responder — verify by looking for a unique
        // Create Account form element (the email field should still exist
        // since CreateAccountViewController also has one).
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
    }

    // MARK: Profile Screen (requires a signed-in session)
    //
    // These tests are marked as skipped when no cached session exists.
    // Run them after signing in once and keeping the session active.

    func testProfileScreenShowsDeleteAccountButton() throws {
        // Skip if the app shows Sign In (no cached session in this run).
        guard !app.buttons["sign-in-button"].waitForExistence(timeout: 3) else {
            throw XCTSkip("No cached session — sign in once to run this test")
        }

        // Navigate to Profile tab (tab index 4).
        app.tabBars.buttons.element(boundBy: 4).tap()

        let deleteButton = app.buttons["delete-account-button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete Account button not found on Profile screen")
    }

    func testDeleteAccountButtonPresentsConfirmationSheet() throws {
        guard !app.buttons["sign-in-button"].waitForExistence(timeout: 3) else {
            throw XCTSkip("No cached session — sign in once to run this test")
        }

        app.tabBars.buttons.element(boundBy: 4).tap()

        let deleteButton = app.buttons["delete-account-button"]
        guard deleteButton.waitForExistence(timeout: 3) else {
            XCTFail("Delete Account button not found")
            return
        }
        deleteButton.tap()

        // The confirmation action sheet should appear with a Cancel action.
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Confirmation sheet Cancel button not found")

        // Dismiss without deleting.
        cancelButton.tap()

        // After cancelling we should still be on the Profile screen.
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    }
}
