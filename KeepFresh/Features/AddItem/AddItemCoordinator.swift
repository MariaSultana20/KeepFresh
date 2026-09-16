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
    /// Called after a successful save, once the modal has finished
    /// dismissing. Item Details passes this so it can update its own
    /// displayed fields without a separate re-fetch; AppCoordinator passes
    /// this to push the new item's Details page (App Store/Music-style
    /// "add it, then land on the thing you just added").
    private let onSaved: ((Item) -> Void)?

    /// Called once the modal has fully dismissed, whether by Save or
    /// Cancel — after `onSaved` above, if that also fired. Owners
    /// (AppCoordinator, ItemDetailsViewController) MUST set this and use
    /// it to release their strong reference to this coordinator: nothing
    /// else keeps it alive, and without a strong reference the coordinator
    /// is deallocated the instant `start()` returns, silently breaking
    /// both Save and Cancel — see the commit that added this comment.
    var onFinished: (() -> Void)?

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
            self?.finish { self?.onSaved?(item) }
        }
        viewModel.onCancel = { [weak self] in
            self?.finish()
        }
        let editorViewController = ItemEditorViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: editorViewController)
        presentingViewController?.present(navigationController, animated: true)
    }

    /// Single exit path for both Save and Cancel. Dismisses first, runs
    /// `completion` (e.g. the saved-item callback) only once the dismiss
    /// animation has actually finished — never racing a push/pop from that
    /// callback against the modal's own transition — then tells the owner
    /// this coordinator is done so it can release its strong reference.
    private func finish(completion: (() -> Void)? = nil) {
        presentingViewController?.dismiss(animated: true) { [weak self] in
            completion?()
            self?.onFinished?()
        }
    }
}
