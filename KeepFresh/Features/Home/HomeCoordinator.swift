import UIKit

/// Owns the Home tab's navigation stack within the signed-in tab bar shell.
@MainActor
final class HomeCoordinator {

    /// Bubbled up to AppCoordinator, which owns the actual modal
    /// presentation — mirrors `ProfileCoordinator.onSignOut`.
    var onAddItemTapped: (() -> Void)?

    private let navigationController: UINavigationController
    private let user: AuthUser
    private let itemRepository: ItemRepository

    init(navigationController: UINavigationController, user: AuthUser, itemRepository: ItemRepository) {
        self.navigationController = navigationController
        self.user = user
        self.itemRepository = itemRepository
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Home", image: UIImage(systemName: "house.fill"), tag: 0
        )
        let homeViewController = HomeViewController(user: user, itemRepository: itemRepository)
        homeViewController.onAddItemTapped = { [weak self] in self?.onAddItemTapped?() }
        navigationController.setViewControllers([homeViewController], animated: false)
    }
}
