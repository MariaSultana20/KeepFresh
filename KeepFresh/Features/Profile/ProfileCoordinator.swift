import UIKit

/// Owns the Profile tab's navigation stack. Editable display name now
/// exists (Edit Profile, pushed); photo editing, notification preferences,
/// and account deletion are the rest of build plan commit 9.
@MainActor
final class ProfileCoordinator {

    /// Bubbled up to AppCoordinator, same as before when this lived on
    /// HomeCoordinator.
    var onSignOut: (() -> Void)?

    private let navigationController: UINavigationController
    private let authService: AuthServiceProtocol
    private var user: AuthUser

    /// Held so a successful Edit Profile save can refresh the
    /// already-presented Profile screen in place, the same way
    /// AppCoordinator holds a weak `tabBarController` to present over it
    /// from more than one call site.
    private weak var profileViewController: ProfileViewController?

    init(navigationController: UINavigationController, user: AuthUser, authService: AuthServiceProtocol) {
        self.navigationController = navigationController
        self.user = user
        self.authService = authService
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Profile", image: UIImage(systemName: "person.crop.circle.fill"), tag: 4
        )
        let profileViewController = ProfileViewController(user: user)
        profileViewController.onSignOutTapped = { [weak self] in
            self?.onSignOut?()
        }
        profileViewController.onEditProfileTapped = { [weak self] in
            self?.showEditProfile()
        }
        self.profileViewController = profileViewController
        navigationController.setViewControllers([profileViewController], animated: false)
    }

    private func showEditProfile() {
        let viewModel = EditProfileViewModel(authService: authService, user: user)
        viewModel.onSaved = { [weak self] updatedUser in
            guard let self else { return }
            user = updatedUser
            profileViewController?.update(user: updatedUser)
            navigationController.popViewController(animated: true)
        }
        let editProfileViewController = EditProfileViewController(viewModel: viewModel)
        navigationController.pushViewController(editProfileViewController, animated: true)
    }
}
