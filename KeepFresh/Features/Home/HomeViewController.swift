import UIKit

/// Home, wired to real data: a greeting header, three summary cards (All
/// Items / Expired / Expiring Soon), and an "Expiring Soon" section showing
/// up to the five soonest-expiring active items — per the design spec, both
/// read from the same `ItemRepository` and refresh every time this screen
/// becomes visible (`viewWillAppear`), which is what picks up an item saved
/// from the Add Item modal, or an edit/delete made from Item Details after
/// popping back, without any extra plumbing between the two.
///
/// Search/filtering and the "See all" action on this section are still
/// ahead (build plan commit 6's remaining scope) — but a row tap now
/// pushes through to Item Details, same as Items' own list.
final class HomeViewController: UIViewController {

    var onAddItemTapped: (() -> Void)?
    var onItemSelected: ((Item) -> Void)?

    private let user: AuthUser
    private let itemRepository: ItemRepository

    private lazy var greetingLabel: UILabel = {
        let label = UILabel()
        let name = user.displayName ?? user.email ?? "there"
        label.text = "Hi, \(name) 👋"
        label.font = AppTheme.Font.title()
        label.textColor = AppTheme.Color.textPrimary
        return label
    }()

    private let summaryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()

    /// Holds either the "Expiring Soon" empty state or up to five
    /// `ItemRowView`s, swapped out on every `refresh()`.
    private let expiringSoonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private let emptyStateView: EmptyStateView = {
        EmptyStateView(
            symbolName: "checkmark.seal",
            title: "Nothing expiring soon",
            actionTitle: "Add an item"
        )
    }()

    init(user: AuthUser, itemRepository: ItemRepository) {
        self.user = user
        self.itemRepository = itemRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.background
        layout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await refresh() }
    }

    private func layout() {
        [SummaryCard.Kind.allItems, .expired, .expiringSoon].forEach { kind in
            summaryStack.addArrangedSubview(SummaryCard(kind: kind, count: 0))
        }

        emptyStateView.onActionTapped = { [weak self] in self?.onAddItemTapped?() }
        expiringSoonStack.addArrangedSubview(emptyStateView)

        let sectionHeader: UILabel = {
            let label = UILabel()
            label.text = "Expiring Soon"
            label.font = AppTheme.Font.headline()
            label.textColor = AppTheme.Color.textPrimary
            return label
        }()

        let stack = UIStackView(arrangedSubviews: [greetingLabel, summaryStack, sectionHeader, expiringSoonStack])
        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(28, after: summaryStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
        ])
    }

    @MainActor
    private func refresh() async {
        // Best-effort: on failure, leave whatever was last displayed rather
        // than blocking this screen with an alert it didn't ask to show —
        // Items' own list is where a user-facing fetch error would surface.
        guard let items = try? await itemRepository.fetchAll() else { return }
        updateSummaryCards(with: items)
        updateExpiringSoonSection(with: items)
    }

    private func updateSummaryCards(with items: [Item]) {
        summaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let expiredCount = items.filter { $0.status() == .expired }.count
        let expiringSoonCount = items.filter { $0.status() == .expiringSoon }.count
        summaryStack.addArrangedSubview(SummaryCard(kind: .allItems, count: items.count))
        summaryStack.addArrangedSubview(SummaryCard(kind: .expired, count: expiredCount))
        summaryStack.addArrangedSubview(SummaryCard(kind: .expiringSoon, count: expiringSoonCount))
    }

    private func updateExpiringSoonSection(with items: [Item]) {
        expiringSoonStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if items.isEmpty {
            expiringSoonStack.addArrangedSubview(emptyStateView)
        } else {
            // itemRepository.fetchAll() is already sorted by expiry date
            // ascending, so the first five are the soonest-expiring.
            for item in items.prefix(5) {
                let row = ItemRowView(item: item)
                row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
                expiringSoonStack.addArrangedSubview(row)
            }
        }
    }

    @objc private func rowTapped(_ sender: ItemRowView) {
        onItemSelected?(sender.item)
    }
}

/// One of the three tappable summary cards at the top of Home.
private final class SummaryCard: UIView {
    enum Kind {
        case allItems, expired, expiringSoon

        var title: String {
            switch self {
            case .allItems: return "All Items"
            case .expired: return "Expired"
            case .expiringSoon: return "Expiring Soon"
            }
        }

        var color: UIColor {
            switch self {
            case .allItems: return AppTheme.Color.textPrimary
            case .expired: return AppTheme.Color.expired
            case .expiringSoon: return AppTheme.Color.expiringSoon
            }
        }
    }

    init(kind: Kind, count: Int) {
        super.init(frame: .zero)
        backgroundColor = AppTheme.Color.cardBackground
        layer.cornerRadius = AppTheme.Metrics.cardCornerRadius

        let countLabel = UILabel()
        countLabel.text = "\(count)"
        countLabel.font = .systemFont(ofSize: 22, weight: .bold)
        countLabel.textColor = kind.color

        let titleLabel = UILabel()
        titleLabel.text = kind.title
        titleLabel.font = AppTheme.Font.caption()
        titleLabel.textColor = AppTheme.Color.textSecondary
        titleLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [countLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
