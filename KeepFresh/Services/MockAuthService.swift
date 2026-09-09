import Foundation

/// In-memory placeholder so the app is runnable end-to-end before real
/// authentication is wired up. Simulates network latency and the validation
/// a real backend would perform, but nothing here persists past the process
/// lifetime and nothing is actually verified.
///
/// Replace with `FirebaseAuthService` in the "wire up authentication" commit;
/// do not extend this type with real credential handling.
final class MockAuthService: AuthServiceProtocol {

    private let simulatedLatencyNanoseconds: UInt64 = 400_000_000

    func signInWithApple() async throws -> AuthUser {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        return AuthUser(id: "mock-apple-user", email: nil, displayName: "Apple User")
    }

    func signInWithGoogle() async throws -> AuthUser {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        return AuthUser(id: "mock-google-user", email: "user@gmail.com", displayName: "Google User")
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        guard password.count >= 6 else { throw AuthError.weakPassword }
        guard email.contains("@") else { throw AuthError.invalidCredentials }
        return AuthUser(id: "mock-email-\(email)", email: email, displayName: nil)
    }

    func signUp(email: String, password: String) async throws -> AuthUser {
        try await signIn(email: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        guard email.contains("@") else { throw AuthError.invalidCredentials }
        // Deliberately succeeds regardless of whether the email is
        // "registered" in this mock — see the protocol doc comment.
    }

    func signOut() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}
