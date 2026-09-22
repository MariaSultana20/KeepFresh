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
    /// Retained only while the Add Item modal is on screen — released via
    /// `onFinished` once it dismisses. Without this the coordinator
    /// deallocates before the user can ever tap Save (see
    /// `AddItemCoordinator.onFinished`).
    private var addItemCoordinator: AddItemCoordinator?

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
        authService: AuthServiceProtocol = FirebaseAuthService(),
        notificationService: NotificationServiceProtocol = LocalNotificationService()
    ) {
        self.window = window
        self.itemRepository = itemRepository
        self.authService = authService
        self.notificationService = notificationService
        super.init()
    }

    func start() {
        // A persisted session skips Sign In entirely rather than making
        // the user log in again every launch — see
        // AuthServiceProtocol.restoreSession() for why this has to be
        // awaited rather than read synchronously. The placeholder covers
        // the (normally near-instant, no network involved) gap while
        // that's in flight, so there's no flash of Sign In before
        // snapping to Home when a session does exist.
        window.rootViewController = launchPlaceholder()
        window.makeKeyAndVisible()
        Task {
            if let user = await authService.restoreSession() {
                showSignedInInterface(for: user, animated: false)
            } else {
                showAuthFlow()
            }
        }
    }

    /// Shown only for the brief window `restoreSession()` takes to check
    /// for a locally-cached session. Matches the plain background of
    /// `UILaunchScreen` in Info.plist so it reads as a continuation of
    /// the system launch screen rather than a distinct extra screen.
    private func launchPlaceholder() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = AppTheme.Color.background
        return viewController
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

    private func showSignedInInterface(for user: AuthUser, animated: Bool = true) {
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
        let notificationsCoordinator = NotificationsCoordinator(
            navigationController: notificationsNavigationController,
            itemRepository: itemRepository, notificationService: notificationService
        )
        notificationsCoordinator.start()
        self.notificationsCoordinator = notificationsCoordinator

        let profileNavigationController = UINavigationController()
        let profileCoordinator = ProfileCoordinator(
            navigationController: profileNavigationController, user: user, authService: authService
        )
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

        window.setRootViewController(tabBarController, animated: animated)
    }

    /// Presents the Add Item modal over the current tab bar shell. Shared by
    /// the Add Item tab intercept and by Home's/Items' own "Add an item"
    /// buttons so there's exactly one place that knows how that modal gets
    /// presented.
    private func presentAddItem() {
        guard let tabBarController else { return }
        let coordinator = AddItemCoordinator(
            presentingViewController: tabBarController,
            itemRepository: itemRepository, notificationService: notificationService
        ) { [weak self] item in
            self?.showItemDetails(for: item)
        }
        coordinator.onFinished = { [weak self] in self?.addItemCoordinator = nil }
        addItemCoordinator = coordinator
        coordinator.start()
    }

    /// Pushes the newly added item's Details page onto whichever tab was
    /// active when Add Item was tapped, once the modal has finished
    /// dismissing — the App Store/Music "add it, then land on the thing
    /// you just added" pattern, matching Home's/Items' own row-tap
    /// navigation to the same screen.
    private func showItemDetails(for item: Item) {
        guard let navigationController = tabBarController?.selectedViewController as? UINavigationController else { return }
        let detailsViewController = ItemDetailsViewController(
            item: item, itemRepository: itemRepository, notificationService: notificationService
        )
        navigationController.pushViewController(detailsViewController, animated: true)
    }

    private func signOut() {
        Task {
            do {
                try await authService.signOut()
                showAuthFlow()
            } catch {
                presentSignOutError(error)
            }
        }
    }

    /// A failed sign-out leaves the signed-in UI on screen rather than
    /// navigating to the auth flow as if it had succeeded — against
    /// `MockAuthService` this path was unreachable (`signOut()` never
    /// threw), but a real backend can genuinely fail here, and silently
    /// treating that as success would leave the user believing they're
    /// signed out while the app is still in a signed-in state.
    private func presentSignOutError(_ error: Error) {
        let message = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        let alert = UIAlertController(
            title: "Couldn't Sign Out",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        window.rootViewController?.present(alert, animated: true)
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
