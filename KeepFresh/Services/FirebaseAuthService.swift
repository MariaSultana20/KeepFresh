import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
import UIKit

/// Real backend for `AuthServiceProtocol`: Firebase Auth's Apple, Google,
/// and email/password providers. Replaces `MockAuthService` per the build
/// plan's commit 10 — no view controller or `AuthViewModel` change needed,
/// since both depend only on the protocol.
///
/// `AuthenticationServices` and `GoogleSignIn` both need a presentation
/// anchor that the protocol's deliberately UIKit-free signature (see
/// `AuthServiceProtocol.swift`) doesn't carry. Rather than thread a
/// `UIViewController` through `AuthViewModel` — which would undo the
/// "UIKit-free, unit-testable" property the original design called out —
/// this type finds the key window / topmost presented view controller
/// itself, the same way `AppCoordinator` already owns `window` as the
/// single source of truth for presentation.
final class FirebaseAuthService: NSObject, AuthServiceProtocol {

    // MARK: AuthServiceProtocol

    func signInWithApple() async throws -> AuthUser {
        let nonce = Self.randomNonceString()
        let credential = try await performAppleRequest(hashedNonce: Self.sha256(nonce))

        guard let identityToken = credential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.unknown("Apple didn't return an identity token.")
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            // Apple only hands us `fullName` on the very first
            // authorization. `appleCredential(fullName:)` already lets
            // Firebase set it on account creation; this is just a
            // defensive fallback in case that didn't happen.
            try await applyDisplayNameIfNeeded(from: credential.fullName, to: result.user)
            return Self.authUser(from: result.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signInWithGoogle() async throws -> AuthUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            // GoogleService-Info.plist has no CLIENT_ID, which means
            // Google wasn't enabled as a sign-in provider (or the file
            // predates enabling it) when it was downloaded from the
            // Firebase console. Re-download it after enabling Google
            // under Authentication -> Sign-in method and drop it back
            // into the Xcode project — nothing else needs to change.
            throw AuthError.unknown(
                "Google Sign-In isn't configured yet: GoogleService-Info.plist has no CLIENT_ID. " +
                "Enable Google under Firebase Console > Authentication > Sign-in method, then re-download " +
                "GoogleService-Info.plist and replace it in the project."
            )
        }

        guard let presentingViewController = await Self.topMostViewController() else {
            throw AuthError.unknown("No view controller available to present Google Sign-In.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = signInResult.user.idToken?.tokenString else {
                throw AuthError.unknown("Google didn't return an ID token.")
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: signInResult.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            return Self.authUser(from: authResult.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return Self.authUser(from: result.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signUp(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return Self.authUser(from: result.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        // Firebase only throws here for a malformed address, never for
        // "no account with that email" — already matches the protocol's
        // never-reveal-account-existence contract with no extra work.
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signOut() async throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw Self.mapError(error)
        }
    }

    func updateDisplayName(_ displayName: String, for user: AuthUser) async throws -> AuthUser {
        guard let currentUser = Auth.auth().currentUser, currentUser.uid == user.id else {
            // Firebase only exposes profile updates on the current
            // session, not by arbitrary user id. The caller always
            // passes the signed-in user today, so this should never
            // trip — fail loudly rather than silently updating the
            // wrong profile.
            throw AuthError.unknown("Can't update a profile for a user who isn't the current session.")
        }
        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = displayName
        do {
            try await changeRequest.commitChanges()
            return Self.authUser(from: currentUser)
        } catch {
            throw Self.mapError(error)
        }
    }

    // Firebase caches the last signed-in user locally (Keychain-backed),
    // synchronously available right after FirebaseApp.configure() — no
    // network round trip needed to answer "is anyone signed in".
    var currentUser: AuthUser? {
        Auth.auth().currentUser.map(Self.authUser(from:))
    }

    // MARK: Apple Sign-In (delegate bridging)

    private var appleContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    private func performAppleRequest(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            appleContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func applyDisplayNameIfNeeded(
        from fullName: PersonNameComponents?,
        to firebaseUser: FirebaseAuth.User
    ) async throws {
        guard firebaseUser.displayName == nil, let fullName else { return }
        let formatted = PersonNameComponentsFormatter().string(from: fullName)
        guard !formatted.isEmpty else { return }
        let changeRequest = firebaseUser.createProfileChangeRequest()
        changeRequest.displayName = formatted
        try await changeRequest.commitChanges()
    }

    // MARK: Helpers

    private static func authUser(from firebaseUser: FirebaseAuth.User) -> AuthUser {
        AuthUser(id: firebaseUser.uid, email: firebaseUser.email, displayName: firebaseUser.displayName)
    }

    /// Maps both Firebase's own `NSError`s and the provider SDKs'
    /// cancellation errors onto `AuthError`, so every screen's existing
    /// `error.errorDescription` display path (see `AuthViewModel`) works
    /// unchanged against the real backend.
    private static func mapError(_ error: Error) -> AuthError {
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .emailAlreadyInUse:
                return .emailAlreadyInUse
            case .wrongPassword, .userNotFound, .invalidEmail, .invalidCredential, .userDisabled:
                return .invalidCredentials
            case .weakPassword:
                return .weakPassword
            case .networkError:
                return .network
            default:
                return .unknown(nsError.localizedDescription)
            }
        }

        if let signInError = error as? GIDSignInError, signInError.code == .canceled {
            return .cancelled
        }

        return .unknown(nsError.localizedDescription)
    }

    @MainActor
    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    @MainActor
    private static func topMostViewController() -> UIViewController? {
        var top = keyWindow()?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Standard Apple/Firebase-recommended nonce generation for the
    /// Sign in with Apple replay-protection handshake — see
    /// https://firebase.google.com/docs/auth/ios/apple.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "Unable to generate a secure nonce.")

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension FirebaseAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { appleContinuation = nil }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleContinuation?.resume(throwing: AuthError.unknown("Unexpected Apple credential type."))
            return
        }
        appleContinuation?.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { appleContinuation = nil }
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            appleContinuation?.resume(throwing: AuthError.cancelled)
        } else {
            appleContinuation?.resume(throwing: Self.mapError(error))
        }
    }
}

extension FirebaseAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Falls back to a bare window only if called before any window
        // is key, which shouldn't happen in practice (the auth screens
        // are always presented within a live window).
        Self.keyWindow() ?? ASPresentationAnchor()
    }
}
