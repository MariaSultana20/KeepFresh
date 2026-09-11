import UIKit

/// Full-screen detail view for a single `Item` — pushed from a row tap in
/// either Items or Home's "Expiring Soon" section (see `ItemRowView`'s
/// `.touchUpInside` target-action). Matches the mockup's Item Details
/// layout: an icon well and status badge up top, then each field as its
/// own labeled row, with Edit/Delete as inline actions at the bottom
/// rather than nav-bar buttons. The mockup uses this same layout for both
/// a normal and an already-expired item, so this screen doesn't branch on
/// status beyond the color/text `ExpiryStatus` already drives everywhere
/// else in the app — an expired item just renders its existing red state.
final class ItemDetailsViewController: UIViewController {

    private var item: Item
    private let itemRepository: ItemRepository
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // MARK: Views

    private let iconWell: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Color.cardBackground
        view.layer.cornerRadius = AppTheme.Metrics.cardCornerRadius
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = AppTheme.Color.primary
        return imageView
    }()

    private let statusBadge: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.Font.title()
        label.textColor = AppTheme.Color.textPrimary
        label.numberOfLines = 2
        return label
    }()

    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.Font.body()
        label.textColor = AppTheme.Color.textSecondary
        return label
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private lazy var editButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Edit"
        configuration.image = UIImage(systemName: "pencil")
        configuration.imagePadding = 6
        configuration.baseForegroundColor = AppTheme.Color.primary
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        return button
    }()

    private lazy var deleteButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Delete"
        configuration.image = UIImage(systemName: "trash")
        configuration.imagePadding = 6
        configuration.baseForegroundColor = AppTheme.Color.expired
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        return button
    }()

    init(item: Item, itemRepository: ItemRepository) {
        self.item = item
        self.itemRepository = itemRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.background
        navigationItem.largeTitleDisplayMode = .never
        layout()
        refreshDisplayedFields()
    }

    // MARK: Layout

    private func layout() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconWell.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconWell.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconWell.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),
            iconWell.heightAnchor.constraint(equalToConstant: 200),
        ])

        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        iconWell.addSubview(statusBadge)
        NSLayoutConstraint.activate([
            statusBadge.topAnchor.constraint(equalTo: iconWell.topAnchor, constant: 12),
            statusBadge.trailingAnchor.constraint(equalTo: iconWell.trailingAnchor, constant: -12),
            statusBadge.heightAnchor.constraint(equalToConstant: 24),
        ])

        let headerStack = UIStackView(arrangedSubviews: [nameLabel, categoryLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4

        let actionsStack = UIStackView(arrangedSubviews: [editButton, deleteButton])
        actionsStack.axis = .horizontal
        actionsStack.spacing = 24

        let contentStack = UIStackView(arrangedSubviews: [iconWell, headerStack, rowsStack, actionsStack])
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.setCustomSpacing(28, after: rowsStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

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
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
        ])
    }

    // MARK: Content

    private func refreshDisplayedFields() {
        title = item.name
        nameLabel.text = item.name
        categoryLabel.text = item.category

        // A generic, category-driven icon rather than a user photo — the
        // mockup's own "Add Manually" form never actually collects a photo
        // either. CategoryIcon (a follow-up commit) replaces this fixed
        // symbol with a per-category one; this screen just needs the well
        // to already exist so that follow-up is a one-line swap here.
        iconImageView.image = UIImage(systemName: "shippingbox.fill")

        let status = item.status()
        statusBadge.text = "  \(status.label)  "
        statusBadge.backgroundColor = status.color

        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowsStack.addArrangedSubview(DetailRow(
            icon: "shippingbox", title: "Quantity",
            value: "\(ItemDetailsViewController.quantityText(for: item.quantity)) \(item.unit.displayName)"
        ))
        if let purchaseDate = item.purchaseDate {
            rowsStack.addArrangedSubview(DetailRow(
                icon: "calendar", title: "Purchase Date",
                value: ItemDetailsViewController.dateFormatter.string(from: purchaseDate)
            ))
        }
        let expiryText = ExpiryStatusCalculator.displayText(for: item.expiryDate)
        rowsStack.addArrangedSubview(DetailRow(
            icon: "calendar.badge.clock", title: "Expiry Date",
            value: ItemDetailsViewController.dateFormatter.string(from: item.expiryDate),
            detail: expiryText, detailColor: status.color
        ))
        rowsStack.addArrangedSubview(DetailRow(icon: "tag", title: "Category", value: item.category))
        if let note = item.note, !note.isEmpty {
            rowsStack.addArrangedSubview(DetailRow(icon: "note.text", title: "Notes", value: note))
        }
    }

    // Same rounding rule as ItemRowView's quantity formatting; kept as its
    // own copy rather than a shared reach-across since the two screens
    // already have their own independent duplicate today too (see the
    // accompanying review's tech-debt notes) — worth a small shared
    // formatter later, not blocking this screen on it now.
    private static func quantityText(for value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    // MARK: Actions

    @objc private func editTapped() {
        AddItemCoordinator(
            presentingViewController: self, itemRepository: itemRepository, existingItem: item
        ) { [weak self] updatedItem in
            self?.item = updatedItem
            self?.refreshDisplayedFields()
        }.start()
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(
            title: "Delete \(item.name)?", message: "This can't be undone.", preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task { await self?.performDelete() }
        })
        present(alert, animated: true)
    }

    @MainActor
    private func performDelete() async {
        do {
            try await itemRepository.delete(id: item.id)
            feedbackGenerator.notificationOccurred(.success)
            navigationController?.popViewController(animated: true)
        } catch {
            feedbackGenerator.notificationOccurred(.error)
            let alert = UIAlertController(
                title: "Couldn't Delete", message: error.localizedDescription, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

/// One labeled field row (icon, title, value, optional colored detail) —
/// the mockup's repeated "Quantity / Purchase Date / Expiry Date / ..."
/// layout, factored into one type so ItemDetailsViewController's body
/// stays declarative rather than hand-laying-out five near-identical rows.
private final class DetailRow: UIView {
    init(icon: String, title: String, value: String, detail: String? = nil, detailColor: UIColor? = nil) {
        super.init(frame: .zero)

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppTheme.Color.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.Font.caption()
        titleLabel.textColor = AppTheme.Color.textSecondary

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.Font.body()
        valueLabel.textColor = AppTheme.Color.textPrimary
        valueLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        var arranged: [UIView] = [iconView, textStack]
        if let detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = AppTheme.Font.caption()
            detailLabel.textColor = detailColor ?? AppTheme.Color.textSecondary
            detailLabel.textAlignment = .right
            detailLabel.setContentHuggingPriority(.required, for: .horizontal)
            arranged.append(detailLabel)
        }

        let rowStack = UIStackView(arrangedSubviews: arranged)
        rowStack.axis = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = 12
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
