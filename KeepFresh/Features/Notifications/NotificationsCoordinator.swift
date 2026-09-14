import UIKit

/// Owns the Notifications tab's navigation stack. Real notification
/// scheduling now exists (`NotificationServiceProtocol`, previous commit),
/// so this reads pending reminders and pushes Item Details on a tap the
/// same way Home/Items do.
@MainActor
final class NotificationsCoordinator {

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
            title: "Notifications", image: UIImage(systemName: "bell.fill"), tag: 3
        )
        let notificationsViewController = NotificationsViewController(
            itemRepository: itemRepository, notificationService: notificationService
        )
        notificationsViewController.onItemSelected = { [weak self] item in self?.showItemDetails(for: item) }
        navigationController.setViewControllers([notificationsViewController], animated: false)
    }

    private func showItemDetails(for item: Item) {
        let detailsViewController = ItemDetailsViewController(
            item: item, itemRepository: itemRepository, notificationService: notificationService
        )
        navigationController.pushViewController(detailsViewController, animated: true)
    }
}
