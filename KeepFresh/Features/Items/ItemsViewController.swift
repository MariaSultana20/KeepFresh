import UIKit

/// Items tab, wired to real data: every item from `ItemRepository` in a
/// scrollable list (already sorted by expiry date ascending), or the empty
/// state when there are none. Refreshes on `viewWillAppear`, which is what
/// picks up an item saved from the Add Item modal, or an edit/delete made
/// from Item Details after popping back.
///
/// Search and a status filter now sit above the list — see
/// `claude/KeepFresh-Mockup-Gap-Analysis-and-Plan.md` Phase B items 6+8.
/// Category filter + sort order are still ahead. Each row pushes through
/// to Item Details.
final class ItemsViewController: UIViewController {

    private enum StatusFilter: Int, CaseIterable {
        case all, expired, expiringSoon, good

        var title: String {
            switch self {
            case .all: return "All"
            case .expired: return "Expired"
            case .expiringSoon: return "Expiring Soon"
            case .good: return "Good"
            }
        }
    }

    var onAddItemTapped: (() -> Void)?
    var onItemSelected: ((Item) -> Void)?

    private let itemRepository: ItemRepository

    /// Every item from the repository, unfiltered — `filteredItems`
    /// derives the displayed list from this plus the search text and
    /// `selectedStatusFilter`, both applied client-side. The dataset is
    /// small and entirely local, so there's no need to push filtering into
    /// the repository layer or debounce the search field the way a
    /// network-backed search would.
    private var allItems: [Item] = []
    private var selectedStatusFilter: StatusFilter = .all

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = "Search by name or category"
        return controller
    }()

    private lazy var statusFilterControl: UISegmentedControl = {
        let control = UISegmentedControl(items: StatusFilter.allCases.map(\.title))
        control.selectedSegmentIndex = StatusFilter.all.rawValue
        control.addTarget(self, action: #selector(statusFilterChanged), for: .valueChanged)
        return control
    }()

    private let emptyStateView = EmptyStateView(
        symbolName: "shippingbox",
        title: "No items yet",
        actionTitle: "Add an item"
    )

    private let noResultsView = EmptyStateView(
        symbolName: "magnifyingglass",
        title: "No items match your search or filter",
        actionTitle: nil
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
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
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
        allItems = items
        render()
    }

    /// Rebuilds the visible rows from `allItems` plus the current search
    /// text and status filter — called on refresh, on every search-text
    /// change, and whenever the status filter changes.
    private func render() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !allItems.isEmpty else {
            contentStack.addArrangedSubview(emptyStateView)
            return
        }

        contentStack.addArrangedSubview(statusFilterControl)

        let visibleItems = filteredItems()
        if visibleItems.isEmpty {
            contentStack.addArrangedSubview(noResultsView)
        } else {
            for item in visibleItems {
                let row = ItemRowView(item: item)
                row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
                contentStack.addArrangedSubview(row)
            }
        }
    }

    private func filteredItems() -> [Item] {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return allItems.filter { item in
            matchesStatusFilter(item) && matchesSearch(item, query: query)
        }
    }

    private func matchesStatusFilter(_ item: Item) -> Bool {
        switch selectedStatusFilter {
        case .all: return true
        case .expired: return item.status() == .expired
        case .expiringSoon: return item.status() == .expiringSoon
        case .good: return item.status() == .good
        }
    }

    /// Case- and diacritic-insensitive, per implementation-plan.md §4's
    /// Items spec — `localizedStandardContains` already gives us that
    /// without hand-rolling folding/normalization.
    private func matchesSearch(_ item: Item, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return item.name.localizedStandardContains(query) || item.category.localizedStandardContains(query)
    }

    @objc private func statusFilterChanged() {
        selectedStatusFilter = StatusFilter(rawValue: statusFilterControl.selectedSegmentIndex) ?? .all
        render()
    }

    @objc private func rowTapped(_ sender: ItemRowView) {
        onItemSelected?(sender.item)
    }
}

extension ItemsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        render()
    }
}
