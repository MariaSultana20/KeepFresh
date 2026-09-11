import Combine
import Foundation

/// Per-field validation result for the email/password form. Kept separate
/// from `errorMessage` (which is for errors the *service* returns, e.g. bad
/// network) so the UI can show "Enter a valid email" directly under the
/// email field rather than in one shared banner.
struct EmailFormValidation {
    var emailError: String?
    var passwordError: String?
    var confirmPasswordError: String?

    var isValid: Bool {
        emailError == nil && passwordError == nil && confirmPasswordError == nil
    }
}

/// Owns loading/error state for the auth screens and talks to
/// `AuthServiceProtocol`. View controllers bind to `$isLoading` /
/// `$errorMessage` and call the methods below; they never call
/// `AuthServiceProtocol` directly. Deliberately UIKit-free (no haptics,
/// no alerts) so it stays testable and reusable between Sign In and
/// Create Account — those UI-layer touches live in the view controllers.
@MainActor
final class AuthViewModel {

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Set after a successful `sendPasswordReset` call so the view
    /// controller can show a one-time confirmation.
    @Published private(set) var passwordResetSent = false

    /// Set by the coordinator; called once a sign-in attempt succeeds.
    var onAuthenticated: ((AuthUser) -> Void)?

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    func signInWithApple() {
        run { try await self.authService.signInWithApple() }
    }

    func signInWithGoogle() {
        run { try await self.authService.signInWithGoogle() }
    }

    func signIn(email: String, password: String) {
        run { try await self.authService.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) {
        run { try await self.authService.signUp(email: email, password: password) }
    }

    func sendPasswordReset(email: String) {
        guard EmailValidator.isValid(email) else {
            errorMessage = "Enter a valid email address first."
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await authService.sendPasswordReset(email: email)
                passwordResetSent = true
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Validates the sign-in form (email + password) client-side before
    /// hitting the service, so the service only ever sees well-formed input
    /// and the UI can point at the specific field that's wrong.
    func validateSignIn(email: String, password: String) -> EmailFormValidation {
        var result = EmailFormValidation()
        if !EmailValidator.isValid(email) {
            result.emailError = "Enter a valid email address."
        }
        if password.count < 6 {
            result.passwordError = "Password must be at least 6 characters."
        }
        return result
    }

    /// Same as `validateSignIn`, plus a password-confirmation check for the
    /// Create Account screen.
    func validateSignUp(email: String, password: String, confirmPassword: String) -> EmailFormValidation {
        var result = validateSignIn(email: email, password: password)
        if result.passwordError == nil, password != confirmPassword {
            result.confirmPasswordError = "Passwords don't match."
        }
        return result
    }

    private func run(_ operation: @escaping () async throws -> AuthUser) {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let user = try await operation()
                onAuthenticated?(user)
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
