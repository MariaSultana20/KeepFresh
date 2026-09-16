import UIKit

/// Owns the Items tab's navigation stack. Wired to real data (list only —
/// search, category grouping, and filter/sort are still ahead, see the
/// accompanying review) and now pushes Item Details on a row tap.
@MainActor
final class ItemsCoordinator {

    /// Bubbled up to AppCoordinator, which owns the actual modal
    /// presentation — mirrors `ProfileCoordinator.onSignOut`.
    var onAddItemTapped: (() -> Void)?

    private let navigationController: UINavigationController
    private let itemRepository: ItemRepository
    private let notificationService: NotificationServiceProtocol

    init(
        navigationController: UINavigationController,
        itemRepository: ItemRepository, notificationService: NotificationServiceProtocol
    ) {
        self.navigationController = navigationController
        self.itemRepository = itemRepository
        self.notificationService = notificationService
    }

    func start() {
        navigationController.tabBarItem = UITabBarItem(
            title: "Items", image: UIImage(systemName: "list.bullet"), tag: 1
        )
        let itemsViewController = ItemsViewController(itemRepository: itemRepository)
        itemsViewController.onAddItemTapped = { [weak self] in self?.onAddItemTapped?() }
        itemsViewController.onItemSelected = { [weak self] item in self?.showItemDetails(for: item) }
        navigationController.setViewControllers([itemsViewController], animated: false)
    }

    private func showItemDetails(for item: Item) {
        let detailsViewController = ItemDetailsViewController(
            item: item, itemRepository: itemRepository, notificationService: notificationService
        )
        navigationController.pushViewController(detailsViewController, animated: true)
    }
}
