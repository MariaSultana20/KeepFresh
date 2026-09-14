import Foundation

/// A signed-in user, independent of which provider authenticated them.
struct AuthUser: Equatable {
    let id: String
    let email: String?
    let displayName: String?
}

enum AuthError: LocalizedError, Equatable {
    case cancelled
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case network
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil // user-initiated cancel; nothing to show
        case .invalidCredentials:
            return "That email or password looks wrong."
        case .emailAlreadyInUse:
            return "An account with that email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .network:
            return "Couldn't reach the network. Check your connection and try again."
        case .unknown(let message):
            return message
        }
    }
}

/// Abstraction over however the app actually authenticates a user.
///
/// `MockAuthService` is the only conformer today. The v1 scope (confirmed:
/// local-only storage, Firebase used for auth only) replaces it with a
/// `FirebaseAuthService` backed by Firebase Auth's Sign in with Apple,
/// Google, and email/password providers — no Firestore or Storage. Every
/// screen in `Features/Auth` and `AppCoordinator` depends only on this
/// protocol, so that swap should not touch any view controller.
protocol AuthServiceProtocol {
    func signInWithApple() async throws -> AuthUser
    func signInWithGoogle() async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(email: String, password: String) async throws -> AuthUser
    /// Always succeeds from the caller's point of view regardless of whether
    /// the email is registered — never reveal account existence through this
    /// call's outcome.
    func sendPasswordReset(email: String) async throws
    func signOut() async throws
}
