import UIKit

/// Root coordinator. Owns the window and decides whether the user sees the
/// auth flow or the signed-in app shell — nothing else should touch
/// `window.rootViewController` directly.
///
/// Scope note: today "signed in" just pushes `HomeViewController` in a plain
/// `UINavigationController`. The five-tab shell (Home, Items, Add Item,
/// Notifications, Profile) described in the build plan's step 3 replaces this
/// with a `UITabBarController` once those features exist — that's an isolated
/// change to `showSignedInInterface()` below, not a rewrite of the coordinators
/// built here.
@MainActor
final class AppCoordinator {

    private let window: UIWindow
    private let authService: AuthServiceProtocol
    private var authCoordinator: AuthCoordinator?
    private var homeCoordinator: HomeCoordinator?

    init(window: UIWindow, authService: AuthServiceProtocol = MockAuthService()) {
        self.window = window
        self.authService = authService
    }

    func start() {
        showAuthFlow()
        window.makeKeyAndVisible()
    }

    private func showAuthFlow() {
        homeCoordinator = nil
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
        let navigationController = UINavigationController()

        let coordinator = HomeCoordinator(navigationController: navigationController, user: user)
        coordinator.onSignOut = { [weak self] in
            self?.signOut()
        }
        homeCoordinator = coordinator
        coordinator.start()

        window.setRootViewController(navigationController, animated: true)
    }

    private func signOut() {
        Task {
            try? await authService.signOut()
            showAuthFlow()
        }
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
