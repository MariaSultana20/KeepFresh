import UIKit

/// Owns the Home tab's navigation stack within the signed-in tab bar shell.
@MainActor
final class HomeCoordinator {

    /// Bubbled up to AppCoordinator, which owns the actual modal
    /// presentation — mirrors `ProfileCoordinator.onSignOut`.
    var onAddItemTapped: (() -> Void)?

    private let navigationController: UINavigationController
    private let itemRepository: ItemRepository
    private let notificationService: NotificationServiceProtocol
    private weak var homeViewController: HomeViewController?

    init(
        navigationController: UINavigationController, user: AuthUser,
        itemRepository: ItemRepository, notificationService: NotificationServiceProtocol
    ) {
        self.navigationController = navigationController
        self.itemRepository = itemRepository
        self.notificationService = notificationService
        self._initialUser = user
    }

    private let _initialUser: AuthUser

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Home", image: UIImage(systemName: "house.fill"), tag: 0
        )
        let homeViewController = HomeViewController(user: _initialUser, itemRepository: itemRepository)
        homeViewController.onAddItemTapped = { [weak self] in self?.onAddItemTapped?() }
        homeViewController.onItemSelected = { [weak self] item in self?.showItemDetails(for: item) }
        self.homeViewController = homeViewController
        navigationController.setViewControllers([homeViewController], animated: false)
    }

    func update(user: AuthUser) {
        homeViewController?.update(user: user)
    }

    private func showItemDetails(for item: Item) {
        let detailsViewController = ItemDetailsViewController(
            item: item, itemRepository: itemRepository, notificationService: notificationService
        )
        navigationController.pushViewController(detailsViewController, animated: true)
    }
}
