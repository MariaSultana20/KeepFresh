import GoogleSignIn
import SwiftData
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("SceneDelegate requires AppDelegate to own the SwiftData ModelContainer")
        }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Automated screenshot capture (scripts/capture-screenshots.sh) runs
        // the app with -screenshotMode to render one seeded screen in
        // isolation, bypassing Firebase sign-in and SwiftData entirely. This
        // branch is dead code in normal use — nothing else sets that flag.
        if ScreenshotSupport.isActive {
            window.rootViewController = ScreenshotRouter.makeRoot()
            window.makeKeyAndVisible()
            return
        }

        let itemRepository = SwiftDataItemRepository(modelContext: appDelegate.modelContainer.mainContext)
        let coordinator = AppCoordinator(
            window: window,
            itemRepository: itemRepository,
            authService: FirebaseAuthService()
        )
        appCoordinator = coordinator
        coordinator.start()
    }

    /// Completes Google Sign-In's OAuth redirect back into the app.
    /// `GIDSignIn` inspects the URL itself and returns `false` for
    /// anything it doesn't recognize, so it's safe to call unconditionally
    /// here rather than trying to pre-filter by scheme.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Screenshot capture support

/// Deterministic, seeded entry point used only for automated screenshot
/// capture (see `scripts/capture-screenshots.sh`). Completely inert in
/// normal use: `SceneDelegate` only consults it when the process is launched
/// with `-screenshotMode`, so the shipping app never touches any of this. It
/// lets each screen be rendered in isolation against in-memory fakes — no
/// Firebase sign-in, no SwiftData, no notification permission prompt — so
/// captures are reliable and reproducible. Lives here rather than in its own
/// file so it needs no separate Xcode target-membership wiring.
enum ScreenshotSupport {

    /// True when launched with `-screenshotMode` (added by the capture
    /// script's `simctl launch`).
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    /// The single screen to render, from `-screenshotScreen <name>`.
    /// Defaults to `home` if absent.
    static var requestedScreen: String {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-screenshotScreen"),
              flagIndex + 1 < arguments.count
        else { return "home" }
        return arguments[flagIndex + 1]
    }
}

/// Builds a fully-wired root view controller for a single named screen,
/// backed by seeded in-memory fakes. Kept separate from `AppCoordinator` so
/// production navigation stays untouched.
@MainActor
enum ScreenshotRouter {

    private static let user = AuthUser(id: "demo", email: "maria@example.com", displayName: "Maria")

    static func makeRoot() -> UIViewController {
        // One seed array shared by the repository and the notification
        // service — regenerating it would mint fresh UUIDs, so preloaded
        // reminders would reference items the repository doesn't contain and
        // the Notifications screen couldn't resolve them.
        let seed = seedItems()
        let repository = InMemoryItemRepository(seedItems: seed)
        let notifications = InMemoryNotificationService()
        notifications.preload(seed)

        switch ScreenshotSupport.requestedScreen {
        case "signIn":
            return SignInViewController(viewModel: AuthViewModel(authService: MockAuthService()))

        case "items":
            return tabBar(selectedIndex: 1, repository: repository, notifications: notifications)

        case "notifications":
            return tabBar(selectedIndex: 3, repository: repository, notifications: notifications)

        case "profile":
            return tabBar(selectedIndex: 4, repository: repository, notifications: notifications)

        case "addItem":
            // An item whose short purchase→expiry window disables the longer
            // reminder presets — showcases the reminder-window validation and
            // its explanatory caption.
            let sample = Item(
                name: "Whole Milk", category: "Dairy", quantity: 1, unit: .liter,
                purchaseDate: daysFromNow(0), expiryDate: daysFromNow(3), reminderDaysBefore: 1
            )
            let viewModel = ItemEditorViewModel(
                itemRepository: repository, notificationService: notifications, existingItem: sample
            )
            return wrappedInNavigation(ItemEditorViewController(viewModel: viewModel))

        case "itemDetails":
            let details = ItemDetailsViewController(
                item: seed[1], itemRepository: repository, notificationService: notifications
            )
            return wrappedInNavigation(details)

        case "home":
            fallthrough
        default:
            return tabBar(selectedIndex: 0, repository: repository, notifications: notifications)
        }
    }

    /// Mirrors `AppCoordinator`'s signed-in shell (Home, Items, Add,
    /// Notifications, Profile) so tabbed screens capture with authentic
    /// chrome, then selects the requested tab.
    private static func tabBar(
        selectedIndex: Int, repository: ItemRepository, notifications: NotificationServiceProtocol
    ) -> UITabBarController {
        let home = UINavigationController(rootViewController: HomeViewController(user: user, itemRepository: repository))
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house.fill"), tag: 0)

        let items = UINavigationController(rootViewController: ItemsViewController(itemRepository: repository))
        items.tabBarItem = UITabBarItem(title: "Items", image: UIImage(systemName: "list.bullet"), tag: 1)

        let addPlaceholder = UIViewController()
        addPlaceholder.tabBarItem = UITabBarItem(title: "Add Item", image: UIImage(systemName: "plus.circle.fill"), tag: 2)

        let notificationsVC = NotificationsViewController(itemRepository: repository, notificationService: notifications)
        let notificationsNav = UINavigationController(rootViewController: notificationsVC)
        notificationsNav.tabBarItem = UITabBarItem(title: "Notifications", image: UIImage(systemName: "bell.fill"), tag: 3)

        let profile = UINavigationController(rootViewController: ProfileViewController(user: user))
        profile.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person.crop.circle.fill"), tag: 4)

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [home, items, addPlaceholder, notificationsNav, profile]
        tabBarController.tabBar.tintColor = AppTheme.Color.primary
        tabBarController.selectedIndex = selectedIndex
        return tabBarController
    }

    private static func wrappedInNavigation(_ viewController: UIViewController) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = false
        return navigationController
    }

    /// A representative inventory spanning every expiry status and several
    /// categories, with dates anchored to "now" so statuses stay correct
    /// whenever the capture runs.
    private static func seedItems() -> [Item] {
        [
            Item(name: "Greek Yogurt", category: "Dairy", quantity: 2, unit: .piece,
                 purchaseDate: daysFromNow(-10), expiryDate: daysFromNow(-2), reminderDaysBefore: 1),
            Item(name: "Whole Milk", category: "Dairy", quantity: 1, unit: .liter,
                 purchaseDate: daysFromNow(-1), expiryDate: daysFromNow(2), reminderDaysBefore: 1),
            Item(name: "Orange Juice", category: "Beverages", quantity: 1, unit: .liter,
                 purchaseDate: daysFromNow(-2), expiryDate: daysFromNow(4), reminderDaysBefore: 2),
            Item(name: "Sourdough Bread", category: "Bakery", quantity: 1, unit: .piece,
                 purchaseDate: daysFromNow(-1), expiryDate: daysFromNow(20), reminderDaysBefore: 7),
            Item(name: "Shampoo", category: "Cosmetics", quantity: 1, unit: .piece,
                 purchaseDate: daysFromNow(-30), expiryDate: daysFromNow(120), reminderDaysBefore: 14),
            Item(name: "Ibuprofen", category: "Medicine", quantity: 1, unit: .box,
                 purchaseDate: daysFromNow(-30), expiryDate: daysFromNow(300), reminderDaysBefore: 30),
        ]
    }

    private static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
