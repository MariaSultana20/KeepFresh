import UIKit

/// Owns the Home tab's navigation stack. Today Home is the entire signed-in
/// interface; once Items/Add Item/Notifications/Profile build out (build
/// plan step 3), `AppCoordinator` wraps this alongside sibling coordinators
/// in a `UITabBarController` instead of presenting it as the lone root.
@MainActor
final class HomeCoordinator {

    var onSignOut: (() -> Void)?

    private let navigationController: UINavigationController
    private let user: AuthUser

    init(navigationController: UINavigationController, user: AuthUser) {
        self.navigationController = navigationController
        self.user = user
    }

    func start() {
        let homeViewController = HomeViewController(user: user)
        homeViewController.onSignOutTapped = { [weak self] in
            self?.onSignOut?()
        }
        navigationController.setViewControllers([homeViewController], animated: false)
    }
}
