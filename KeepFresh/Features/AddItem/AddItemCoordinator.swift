import UIKit

/// Owns presenting (and dismissing) the Add Item tab's modal. The Add Item
/// tab is never actually selected as the active tab — AppCoordinator
/// intercepts the tap via UITabBarControllerDelegate and calls this
/// instead — per the IA spec: "The Add Item tab presents the editor in a
/// modal UINavigationController and returns to the previously selected tab
/// after save or cancel."
///
/// Presents the real `ItemEditorViewController` in Add mode. Also reusable
/// for Edit — pass the item to edit as `existingItem` (Item Details does
/// this for its own Edit action) and, if the caller needs the saved item
/// back rather than just a dismissal, an `onSaved` closure.
@MainActor
final class AddItemCoordinator {

    private weak var presentingViewController: UIViewController?
    private let itemRepository: ItemRepository
    private let notificationService: NotificationServiceProtocol
    private let existingItem: Item?
    /// Called after a successful save, in addition to (not instead of) the
    /// dismissal below. Item Details passes this so it can update its own
    /// displayed fields without a separate re-fetch; every other call site
    /// (Home/Items' "Add an item" buttons, the Add Item tab) leaves it nil
    /// since a dismiss-and-refresh-on-viewWillAppear is all they need.
    private let onSaved: ((Item) -> Void)?

    init(
        presentingViewController: UIViewController,
        itemRepository: ItemRepository,
        notificationService: NotificationServiceProtocol,
        existingItem: Item? = nil,
        onSaved: ((Item) -> Void)? = nil
    ) {
        self.presentingViewController = presentingViewController
        self.itemRepository = itemRepository
        self.notificationService = notificationService
        self.existingItem = existingItem
        self.onSaved = onSaved
    }

    func start() {
        let viewModel = ItemEditorViewModel(
            itemRepository: itemRepository, notificationService: notificationService, existingItem: existingItem
        )
        viewModel.onSaved = { [weak self] item in
            self?.presentingViewController?.dismiss(animated: true)
            self?.onSaved?(item)
        }
        let editorViewController = ItemEditorViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: editorViewController)
        presentingViewController?.present(navigationController, animated: true)
    }
}
