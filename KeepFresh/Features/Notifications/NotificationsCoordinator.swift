import UIKit

/// Owns the Notifications tab's navigation stack. Real notification
/// history (scheduling, records, deep-linking to an item) is build plan
/// commit 8, once local notifications actually exist to have history —
/// today it's a real empty state.
@MainActor
final class NotificationsCoordinator {

    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Notifications", image: UIImage(systemName: "bell.fill"), tag: 3
        )
        navigationController.setViewControllers([NotificationsViewController()], animated: false)
    }
}
