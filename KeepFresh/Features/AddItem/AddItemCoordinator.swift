import UIKit

/// Owns presenting (and dismissing) the Add Item tab's modal. The Add Item
/// tab is never actually selected as the active tab — AppCoordinator
/// intercepts the tap via UITabBarControllerDelegate and calls this
/// instead — per the IA spec: "The Add Item tab presents the editor in a
/// modal UINavigationController and returns to the previously selected tab
/// after save or cancel." There's no real editor to present yet (build
/// plan commit 7), so this presents a placeholder with the same modal
/// shape (its own UINavigationController) the real editor will use.
@MainActor
final class AddItemCoordinator {

    private weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }

    func start() {
        let placeholder = AddItemPlaceholderViewController()
        placeholder.onCloseTapped = { [weak placeholder] in
            placeholder?.dismiss(animated: true)
        }
        let navigationController = UINavigationController(rootViewController: placeholder)
        presentingViewController?.present(navigationController, animated: true)
    }
}
