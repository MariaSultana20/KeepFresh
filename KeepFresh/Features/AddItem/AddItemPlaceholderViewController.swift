import UIKit

/// Stand-in for the real Item Editor (build plan commit 7) — presented
/// modally when the Add Item tab is tapped, see AddItemCoordinator. A
/// plain "Close" (not "Cancel") since there's no input to discard: this
/// screen shows nothing but a message.
final class AddItemPlaceholderViewController: UIViewController {

    var onCloseTapped: (() -> Void)?

    private let emptyStateView = EmptyStateView(
        symbolName: "plus.circle",
        title: "Adding items isn't built yet.",
        actionTitle: nil
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Item"
        view.backgroundColor = AppTheme.Color.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped)
        )
        layout()
    }

    private func layout() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            emptyStateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
            emptyStateView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    @objc private func closeTapped() {
        onCloseTapped?()
    }
}
