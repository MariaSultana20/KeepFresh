import UIKit

/// Items tab, wired to real data: every item from `ItemRepository` in a
/// scrollable list (already sorted by expiry date ascending), or the empty
/// state when there are none. Refreshes on `viewWillAppear`, which is what
/// picks up an item saved from the Add Item modal, or an edit/delete made
/// from Item Details after popping back.
///
/// Search, category grouping, and filter/sort are still ahead — see the
/// accompanying review — but each row now pushes through to Item Details.
final class ItemsViewController: UIViewController {

    var onAddItemTapped: (() -> Void)?
    var onItemSelected: ((Item) -> Void)?

    private let itemRepository: ItemRepository

    private let emptyStateView = EmptyStateView(
        symbolName: "shippingbox",
        title: "No items yet",
        actionTitle: "Add an item"
    )

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    init(itemRepository: ItemRepository) {
        self.itemRepository = itemRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Items"
        view.backgroundColor = AppTheme.Color.background
        layout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await refresh() }
    }

    private func layout() {
        emptyStateView.onActionTapped = { [weak self] in self?.onAddItemTapped?() }
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
        // Best-effort: leave the list as it was on a fetch failure rather
        // than replacing it with a blocking alert every time this tab is
        // shown.
        guard let items = try? await itemRepository.fetchAll() else { return }
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if items.isEmpty {
            contentStack.addArrangedSubview(emptyStateView)
        } else {
            for item in items {
                let row = ItemRowView(item: item)
                row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
                contentStack.addArrangedSubview(row)
            }
        }
    }

    @objc private func rowTapped(_ sender: ItemRowView) {
        onItemSelected?(sender.item)
    }
}
