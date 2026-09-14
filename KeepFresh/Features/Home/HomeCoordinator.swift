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
    private let notificationService: NotificationServiceProtocol

    init(
        navigationController: UINavigationController, user: AuthUser,
        itemRepository: ItemRepository, notificationService: NotificationServiceProtocol
    ) {
        self.navigationController = navigationController
        self.user = user
        self.itemRepository = itemRepository
        self.notificationService = notificationService
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Home", image: UIImage(systemName: "house.fill"), tag: 0
        )
        let homeViewController = HomeViewController(user: user, itemRepository: itemRepository)
        homeViewController.onAddItemTapped = { [weak self] in self?.onAddItemTapped?() }
        homeViewController.onItemSelected = { [weak self] item in self?.showItemDetails(for: item) }
        navigationController.setViewControllers([homeViewController], animated: false)
    }

    private func showItemDetails(for item: Item) {
        let detailsViewController = ItemDetailsViewController(
            item: item, itemRepository: itemRepository, notificationService: notificationService
        )
        navigationController.pushViewController(detailsViewController, animated: true)
    }
}
