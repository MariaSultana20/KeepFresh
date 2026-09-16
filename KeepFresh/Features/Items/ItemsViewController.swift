import UIKit

/// Items tab, wired to real data: every item from `ItemRepository` in a
/// scrollable list (already sorted by expiry date ascending), or the empty
/// state when there are none. Refreshes on `viewWillAppear`, which is what
/// picks up an item saved from the Add Item modal, or an edit/delete made
/// from Item Details after popping back.
///
/// Search and a status filter sit above the list, and a nav-bar filter
/// menu adds category + sort order on top — see
/// `claude/KeepFresh-Mockup-Gap-Analysis-and-Plan.md` Phase B items 6-8.
/// Each row pushes through to Item Details.
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

    /// Sort order offered by the nav-bar filter menu — "Expiry Date
    /// (Soonest)" matches `ItemRepository.fetchAll()`'s own ordering, so
    /// it's the default rather than a separate re-sort of already-sorted
    /// data.
    private enum SortOrder: CaseIterable {
        case expirySoonest, expiryLatest, nameAscending

        var title: String {
            switch self {
            case .expirySoonest: return "Expiry Date (Soonest)"
            case .expiryLatest: return "Expiry Date (Latest)"
            case .nameAscending: return "Name (A–Z)"
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
    /// nil means "All Categories" — options are derived from whatever
    /// categories are actually present in `allItems`, not a hardcoded
    /// preset list, so a custom "Other" category the user typed shows
    /// up as a real filter option too.
    private var selectedCategory: String?
    private var selectedSortOrder: SortOrder = .expirySoonest

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

    /// Category filter + sort order, per the Mockup-Gap-Analysis's
    /// recommendation: a UIMenu on a nav-bar button rather than a second
    /// pushed "Filter & Sort" screen — a four-ish-item category list and a
    /// three-item sort order don't carry their own screen well, and the
    /// mockup's own inline status pills already cover status filtering
    /// (see the previous commit).
    private lazy var filterBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "line.3.horizontal.decrease.circle")
    )

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
        navigationItem.rightBarButtonItem = filterBarButtonItem
        definesPresentationContext = true
        layout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // UIKit's hidesSearchBarWhenScrolling tracking is only reliable
        // alongside prefersLargeTitles (a compact title was the deliberate
        // choice for this screen, not a large one) - left as-is, the
        // search bar can come back from a push/pop (e.g. Item Details)
        // still in whatever collapsed/hidden state it had when this
        // screen was last visible, instead of fully shown. Disabling the
        // flag here forces the search bar back to its full, visible
        // height on every appearance; re-enabling it in viewDidAppear (
        // below) restores hide-on-scroll for the rest of this visit. This
        // reset-on-appear pattern is the standard workaround for this
        // long-standing UIKit issue.
        navigationItem.hidesSearchBarWhenScrolling = false
        Task { await refresh() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.hidesSearchBarWhenScrolling = true
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
        updateFilterMenu()
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
        let matching = allItems.filter { item in
            matchesStatusFilter(item) && matchesSearch(item, query: query) && matchesCategory(item)
        }
        return sorted(matching)
    }

    private func matchesCategory(_ item: Item) -> Bool {
        guard let selectedCategory else { return true }
        return item.category.trimmingCharacters(in: .whitespaces) == selectedCategory
    }

    private func sorted(_ items: [Item]) -> [Item] {
        switch selectedSortOrder {
        case .expirySoonest:
            return items.sorted { $0.expiryDate < $1.expiryDate }
        case .expiryLatest:
            return items.sorted { $0.expiryDate > $1.expiryDate }
        case .nameAscending:
            return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// Rebuilds the filter menu's two submenus (Category, Sort By) from
    /// the current `allItems`/selection every time it's called, so a
    /// newly-added item's category shows up as a filter option and the
    /// checkmarks always reflect what's actually applied.
    private func updateFilterMenu() {
        let categories = Set(allItems.map { $0.category.trimmingCharacters(in: .whitespaces) })
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        var categoryActions = [UIAction(title: "All Categories", state: selectedCategory == nil ? .on : .off) { [weak self] _ in
            self?.selectedCategory = nil
            self?.render()
        }]
        categoryActions += categories.map { category in
            UIAction(title: category, state: selectedCategory == category ? .on : .off) { [weak self] _ in
                self?.selectedCategory = category
                self?.render()
            }
        }
        let categoryMenu = UIMenu(title: "Category", options: .singleSelection, children: categoryActions)

        let sortActions = SortOrder.allCases.map { order in
            UIAction(title: order.title, state: order == selectedSortOrder ? .on : .off) { [weak self] _ in
                self?.selectedSortOrder = order
                self?.render()
            }
        }
        let sortMenu = UIMenu(title: "Sort By", options: .singleSelection, children: sortActions)

        filterBarButtonItem.menu = UIMenu(children: [categoryMenu, sortMenu])
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
