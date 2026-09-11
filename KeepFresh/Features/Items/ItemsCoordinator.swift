import UIKit

/// Owns the Items tab's navigation stack. Wired to real data (search,
/// list, Item Details) in build plan commit 6 once ItemRepository has a
/// consumer; today it's a real empty state, not a temporary placeholder.
@MainActor
final class ItemsCoordinator {

    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Items", image: UIImage(systemName: "list.bullet"), tag: 1
        )
        navigationController.setViewControllers([ItemsViewController()], animated: false)
    }
}
