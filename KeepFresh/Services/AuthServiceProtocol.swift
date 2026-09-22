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
    /// Returns a copy of `user` with `displayName` updated. Takes the
    /// current user explicitly rather than assuming a "current session"
    /// the protocol doesn't otherwise model — `MockAuthService` has no
    /// backing store to look one up in, and a real implementation
    /// shouldn't need one either to answer "update this user's name."
    func updateDisplayName(_ displayName: String, for user: AuthUser) async throws -> AuthUser

    /// Waits for the locally-persisted session (if any — Apple, Google,
    /// and email/password all end up as the same kind of session once
    /// signed in) to finish restoring, then returns it.
    ///
    /// This is deliberately *not* a synchronous property reading
    /// something like Firebase's own `Auth.auth().currentUser`. That
    /// read races Firebase's own async load of the cached session from
    /// Keychain — called too early (e.g. right after `FirebaseApp.
    /// configure()` at launch) it can return nil even though a session
    /// exists, which is exactly the "sign-in doesn't survive closing the
    /// app" bug this method exists to avoid. `AppCoordinator.start()`
    /// awaits this before deciding whether to show the signed-in
    /// interface or Sign In. `MockAuthService` returns `nil` immediately
    /// — nothing there ever persisted past the process lifetime anyway.
    func restoreSession() async -> AuthUser?
}
