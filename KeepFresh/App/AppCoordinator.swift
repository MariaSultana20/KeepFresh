import UIKit

/// Root coordinator. Owns the window and decides whether the user sees the
/// auth flow or the signed-in app shell — nothing else should touch
/// `window.rootViewController` directly.
///
/// Signed in, the app shell is the five-tab `UITabBarController` from the
/// design spec: Home, Items, Add Item, Notifications, Profile. Add Item has
/// no screen of its own — `UITabBarControllerDelegate` intercepts its
/// selection below and presents `AddItemCoordinator` modally instead,
/// returning to whichever tab was active before (App Store/Music's "+" tab
/// pattern), rather than becoming the active tab itself. Home and Items also
/// each have their own "Add an item" empty-state button, which routes here
/// through the same `presentAddItem()` rather than duplicating the modal
/// presentation logic at each call site.
@MainActor
final class AppCoordinator: NSObject {

    private let window: UIWindow
    private let authService: AuthServiceProtocol
    private let itemRepository: ItemRepository
    private let notificationService: NotificationServiceProtocol

    private var authCoordinator: AuthCoordinator?
    private var homeCoordinator: HomeCoordinator?
    private var itemsCoordinator: ItemsCoordinator?
    private var notificationsCoordinator: NotificationsCoordinator?
    private var profileCoordinator: ProfileCoordinator?

    /// Held so `presentAddItem()` can present over it from any call site
    /// (the tab intercept below, or Home's/Items' "Add an item" buttons),
    /// not just from the `UITabBarControllerDelegate` callback.
    private weak var tabBarController: UITabBarController?

    /// Inert stand-in that occupies the Add Item tab slot. `UITabBarController`
    /// requires a real view controller per tab, but this one is never shown —
    /// `tabBarController(_:shouldSelect:)` intercepts the tap and presents
    /// `AddItemCoordinator` instead, then returns `false` so the tab bar's
    /// selection never actually moves onto it.
    private let addItemTabPlaceholder = UIViewController()

    init(
        window: UIWindow,
        itemRepository: ItemRepository,
        authService: AuthServiceProtocol = MockAuthService(),
        notificationService: NotificationServiceProtocol = LocalNotificationService()
    ) {
        self.window = window
        self.itemRepository = itemRepository
        self.authService = authService
        self.notificationService = notificationService
        super.init()
    }

    func start() {
        showAuthFlow()
        window.makeKeyAndVisible()
    }

    private func showAuthFlow() {
        homeCoordinator = nil
        itemsCoordinator = nil
        notificationsCoordinator = nil
        profileCoordinator = nil
        tabBarController = nil

        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = AuthCoordinator(
            navigationController: navigationController,
            authService: authService
        )
        coordinator.onAuthenticated = { [weak self] user in
            self?.showSignedInInterface(for: user)
        }
        authCoordinator = coordinator
        coordinator.start()

        window.rootViewController = navigationController
    }

    private func showSignedInInterface(for user: AuthUser) {
        authCoordinator = nil

        let homeNavigationController = UINavigationController()
        let homeCoordinator = HomeCoordinator(
            navigationController: homeNavigationController, user: user,
            itemRepository: itemRepository, notificationService: notificationService
        )
        homeCoordinator.onAddItemTapped = { [weak self] in self?.presentAddItem() }
        homeCoordinator.start()
        self.homeCoordinator = homeCoordinator

        let itemsNavigationController = UINavigationController()
        let itemsCoordinator = ItemsCoordinator(
            navigationController: itemsNavigationController,
            itemRepository: itemRepository, notificationService: notificationService
        )
        itemsCoordinator.onAddItemTapped = { [weak self] in self?.presentAddItem() }
        itemsCoordinator.start()
        self.itemsCoordinator = itemsCoordinator

        addItemTabPlaceholder.tabBarItem = UITabBarItem(
            title: "Add Item", image: UIImage(systemName: "plus.circle.fill"), tag: 2
        )

        let notificationsNavigationController = UINavigationController()
        let notificationsCoordinator = NotificationsCoordinator(navigationController: notificationsNavigationController)
        notificationsCoordinator.start()
        self.notificationsCoordinator = notificationsCoordinator

        let profileNavigationController = UINavigationController()
        let profileCoordinator = ProfileCoordinator(navigationController: profileNavigationController, user: user)
        profileCoordinator.onSignOut = { [weak self] in
            self?.signOut()
        }
        profileCoordinator.start()
        self.profileCoordinator = profileCoordinator

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            homeNavigationController,
            itemsNavigationController,
            addItemTabPlaceholder,
            notificationsNavigationController,
            profileNavigationController,
        ]
        tabBarController.tabBar.tintColor = AppTheme.Color.primary
        tabBarController.delegate = self
        self.tabBarController = tabBarController

        window.setRootViewController(tabBarController, animated: true)
    }

    /// Presents the Add Item modal over the current tab bar shell. Shared by
    /// the Add Item tab intercept and by Home's/Items' own "Add an item"
    /// buttons so there's exactly one place that knows how that modal gets
    /// presented.
    private func presentAddItem() {
        guard let tabBarController else { return }
        AddItemCoordinator(
            presentingViewController: tabBarController,
            itemRepository: itemRepository, notificationService: notificationService
        ).start()
    }

    private func signOut() {
        Task {
            try? await authService.signOut()
            showAuthFlow()
        }
    }
}

extension AppCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard viewController === addItemTabPlaceholder else { return true }
        presentAddItem()
        return false
    }
}

extension UIWindow {
    /// Cross-fades to a new root view controller instead of an abrupt swap.
    func setRootViewController(_ viewController: UIViewController, animated: Bool) {
        guard animated else {
            rootViewController = viewController
            return
        }
        UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
            self.rootViewController = viewController
        }
    }
}
