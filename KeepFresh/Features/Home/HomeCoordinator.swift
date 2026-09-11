import UIKit

/// Owns the Home tab's navigation stack within the signed-in tab bar shell.
@MainActor
final class HomeCoordinator {

    private let navigationController: UINavigationController
    private let user: AuthUser

    init(navigationController: UINavigationController, user: AuthUser) {
        self.navigationController = navigationController
        self.user = user
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Home", image: UIImage(systemName: "house.fill"), tag: 0
        )
        let homeViewController = HomeViewController(user: user)
        navigationController.setViewControllers([homeViewController], animated: false)
    }
}
