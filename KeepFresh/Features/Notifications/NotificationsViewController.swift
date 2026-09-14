import UIKit

/// Notifications tab: every item with a currently-scheduled reminder,
/// soonest first, or the empty state when nothing is scheduled. Reads
/// `NotificationServiceProtocol.pendingReminders()` and resolves each
/// `itemID` against `ItemRepository` rather than keeping its own separate,
/// persisted notification-history log (deep-linking to the item and
/// "read/unread" state from implementation-plan.md §4 are cut along with
/// that log — see the accompanying commit message for the full scope
/// note). Refreshes on `viewWillAppear`, same as Home/Items, so scheduling
/// a reminder (Add/Edit) or deleting an item is reflected without extra
/// plumbing.
final class NotificationsViewController: UIViewController {

    var onItemSelected: ((Item) -> Void)?

    private let itemRepository: ItemRepository
    private let notificationService: NotificationServiceProtocol

    private let emptyStateView = EmptyStateView(
        symbolName: "bell",
        title: "No reminders scheduled",
        actionTitle: nil
    )

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }()

    init(itemRepository: ItemRepository, notificationService: NotificationServiceProtocol) {
        self.itemRepository = itemRepository
        self.notificationService = notificationService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        view.backgroundColor = AppTheme.Color.background
        layout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await refresh() }
    }

    private func layout() {
        contentStack.addArrangedSubview(emptyStateView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
        ])
    }

    @MainActor
    private func refresh() async {
        let reminders = await notificationService.pendingReminders()

        // Resolve each reminder's item, dropping any whose item no longer
        // exists (e.g. deleted through some future path that doesn't also
        // cancel its reminder) rather than crashing or showing a blank row.
        var rows: [(item: Item, fireDate: Date)] = []
        for reminder in reminders {
            guard let item = try? await itemRepository.item(id: reminder.itemID) else { continue }
            rows.append((item, reminder.fireDate))
        }
        rows.sort { $0.fireDate < $1.fireDate }

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if rows.isEmpty {
            contentStack.addArrangedSubview(emptyStateView)
        } else {
            for row in rows {
                let reminderRow = ReminderRowView(item: row.item, fireDate: row.fireDate)
                reminderRow.itemRow.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
                contentStack.addArrangedSubview(reminderRow)
            }
        }
    }

    @objc private func rowTapped(_ sender: ItemRowView) {
        onItemSelected?(sender.item)
    }
}

/// A reminder's fire date as a caption above the shared `ItemRowView`
/// (same row Items/Home use), so a reminder in this list still reads as
/// "this item" while adding the one piece of information Items' row
/// doesn't show: when the reminder actually fires.
private final class ReminderRowView: UIView {
    let itemRow: ItemRowView

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(item: Item, fireDate: Date) {
        itemRow = ItemRowView(item: item)
        super.init(frame: .zero)

        let captionLabel = UILabel()
        captionLabel.text = "Reminder \(ReminderRowView.dateFormatter.string(from: fireDate))"
        captionLabel.font = AppTheme.Font.caption()
        captionLabel.textColor = AppTheme.Color.textSecondary

        let stack = UIStackView(arrangedSubviews: [captionLabel, itemRow])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
