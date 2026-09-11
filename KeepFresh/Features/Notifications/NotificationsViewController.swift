import UIKit

/// Notifications tab in its empty (no history yet) state. No action
/// button here — unlike Home/Items, there's nothing to "add" from an empty
/// notification list, so EmptyStateView's actionTitle is nil.
final class NotificationsViewController: UIViewController {

    private let emptyStateView = EmptyStateView(
        symbolName: "bell",
        title: "No notifications yet",
        actionTitle: nil
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        view.backgroundColor = AppTheme.Color.background
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
}
