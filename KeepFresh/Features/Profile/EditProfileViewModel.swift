import Combine
import Foundation

/// Owns validation and persistence for the Edit Profile form — display
/// name only for now, per the Build Plan's "display name at minimum
/// (avatar editing can follow later)" scope for this piece of commit 9.
/// Deliberately UIKit-free, same as `AuthViewModel`/`ItemEditorViewModel`.
@MainActor
final class EditProfileViewModel {

    private let authService: AuthServiceProtocol
    private let user: AuthUser

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Called once save succeeds, with the updated `AuthUser` — the
    /// coordinator uses this to refresh the already-presented Profile
    /// screen rather than requiring a re-fetch.
    var onSaved: ((AuthUser) -> Void)?

    var initialDisplayName: String { user.displayName ?? "" }

    init(authService: AuthServiceProtocol, user: AuthUser) {
        self.authService = authService
        self.user = user
    }

    func validate(displayName: String) -> String? {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter a name." : nil
    }

    func save(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let updatedUser = try await authService.updateDisplayName(trimmed, for: user)
                onSaved?(updatedUser)
            } catch {
                errorMessage = "Couldn't save your profile: \(error.localizedDescription)"
            }
        }
    }
}
