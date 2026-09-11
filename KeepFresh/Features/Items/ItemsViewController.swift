import UIKit

/// Items tab in its empty (no items yet) state. Search, the active item
/// list, and Item Details are build plan commit 6, once ItemRepository is
/// actually wired to real data — this screen intentionally has no data
/// layer yet, matching the shell HomeViewController started as.
final class ItemsViewController: UIViewController {

    private let emptyStateView = EmptyStateView(
        symbolName: "shippingbox",
        title: "No items yet",
        actionTitle: "Add an item"
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Items"
        view.backgroundColor = AppTheme.Color.background
        layout()
    }

    private func layout() {
        emptyStateView.onActionTapped = { [weak self] in
            self?.presentComingSoon()
        }
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            emptyStateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
            emptyStateView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func presentComingSoon() {
        // TODO: route to the Add Item tab / real Item Editor once it
        // exists (build plan commit 7) instead of this placeholder alert —
        // same TODO as HomeViewController's "Add an item" button.
        let alert = UIAlertController(
            title: "Coming soon",
            message: "Adding items isn't built yet.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
