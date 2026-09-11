import Foundation

/// Shared, deliberately simple email validation used by both the sign-in
/// form (`AuthViewModel`) and `MockAuthService`'s server-side re-check —
/// one definition so the two layers can't quietly disagree.
///
/// This is intentionally not a full RFC 5322 implementation (that's usually
/// overkill and a rabbit hole for a login field); it just closes the gap in
/// the previous `email.contains("@") && email.contains(".")` check, which
/// accepted garbage like `"@."` or `"a@.b"`. Real confirmation of an email
/// address still has to happen server-side (verification link, etc.) once
/// a real backend is wired in.
enum EmailValidator {
    static func isValid(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1]
        guard let dotIndex = domain.firstIndex(of: ".") else { return false }
        let hasNonEmptyLocalDomainPart = dotIndex != domain.startIndex
        let hasNonEmptyTLD = domain.index(after: dotIndex) != domain.endIndex
        return hasNonEmptyLocalDomainPart && hasNonEmptyTLD
    }
}
