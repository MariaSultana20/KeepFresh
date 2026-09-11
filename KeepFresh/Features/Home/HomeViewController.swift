import UIKit

/// Home in its empty (no items yet) state, per the design spec: a greeting
/// header, three zeroed summary cards (All Items / Expired / Expiring Soon),
/// and an empty-state "Expiring Soon" section.
///
/// This screen intentionally has no data layer yet — it's the shell described
/// in build plan step 1. Wiring it to a real item count/list is step 3, once
/// `ItemRepository` exists.
final class HomeViewController: UIViewController {

    private let user: AuthUser

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

    private let emptyStateView: EmptyStateView = {
        EmptyStateView(
            symbolName: "checkmark.seal",
            title: "Nothing expiring soon",
            actionTitle: "Add an item"
        )
    }()

    init(user: AuthUser) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.background
        layout()
    }

    private func layout() {
        [SummaryCard.Kind.allItems, .expired, .expiringSoon].forEach { kind in
            summaryStack.addArrangedSubview(SummaryCard(kind: kind, count: 0))
        }

        emptyStateView.onActionTapped = { [weak self] in
            self?.presentComingSoon()
        }

        let sectionHeader: UILabel = {
            let label = UILabel()
            label.text = "Expiring Soon"
            label.font = AppTheme.Font.headline()
            label.textColor = AppTheme.Color.textPrimary
            return label
        }()

        let stack = UIStackView(arrangedSubviews: [greetingLabel, summaryStack, sectionHeader, emptyStateView])
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

    private func presentComingSoon() {
        // TODO: route via AppCoordinator to the Item Editor once it exists
        // (build plan commit 7) instead of showing this placeholder alert.
        let alert = UIAlertController(
            title: "Coming soon",
            message: "Adding items isn't built yet.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
