import UIKit

/// Owns presenting (and dismissing) the Add Item tab's modal. The Add Item
/// tab is never actually selected as the active tab — AppCoordinator
/// intercepts the tap via UITabBarControllerDelegate and calls this
/// instead — per the IA spec: "The Add Item tab presents the editor in a
/// modal UINavigationController and returns to the previously selected tab
/// after save or cancel."
///
/// Presents the real `ItemEditorViewController` in Add mode. Also reusable
/// for Edit once Items/Item Details grows a long-press Edit action (a
/// separate, later commit) — pass the item to edit as `existingItem`.
@MainActor
final class AddItemCoordinator {

    private weak var presentingViewController: UIViewController?
    private let itemRepository: ItemRepository
    private let existingItem: Item?

    init(presentingViewController: UIViewController, itemRepository: ItemRepository, existingItem: Item? = nil) {
        self.presentingViewController = presentingViewController
        self.itemRepository = itemRepository
        self.existingItem = existingItem
    }

    func start() {
        let viewModel = ItemEditorViewModel(itemRepository: itemRepository, existingItem: existingItem)
        viewModel.onSaved = { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: true)
        }
        let editorViewController = ItemEditorViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: editorViewController)
        presentingViewController?.present(navigationController, animated: true)
    }
}
