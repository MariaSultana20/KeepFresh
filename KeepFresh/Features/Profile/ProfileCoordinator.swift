import UIKit

/// Owns the Profile tab's navigation stack. Editable display name/photo,
/// notification preferences, and account deletion are build plan commit 9
/// — today this is the v1 shell: signed-in user info plus Sign Out, which
/// moved here from Home now that a real Profile tab exists.
@MainActor
final class ProfileCoordinator {

    /// Bubbled up to AppCoordinator, same as before when this lived on
    /// HomeCoordinator.
    var onSignOut: (() -> Void)?

    private let navigationController: UINavigationController
    private let user: AuthUser

    init(navigationController: UINavigationController, user: AuthUser) {
        self.navigationController = navigationController
        self.user = user
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Profile", image: UIImage(systemName: "person.crop.circle.fill"), tag: 4
        )
        let profileViewController = ProfileViewController(user: user)
        profileViewController.onSignOutTapped = { [weak self] in
            self?.onSignOut?()
        }
        navigationController.setViewControllers([profileViewController], animated: false)
    }
}
