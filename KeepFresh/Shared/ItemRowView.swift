import UIKit

/// Reusable row for displaying an `Item` — the "common item row" from the
/// design spec (image/name/category/expiry/status/chevron), used by both
/// the Items list and Home's "Expiring Soon" section so the two screens
/// can't drift apart on how a row looks. Matches the `Shared/ItemCell` slot
/// named in the original project structure notes.
///
/// A `UIControl`, not a plain `UIView` with a bolted-on gesture recognizer
/// — the chevron this row already draws promises drill-down, so the row
/// itself should be a real tappable control: `.touchUpInside` gives every
/// call site the standard target-action pattern already used elsewhere in
/// this codebase, plus correct press-highlight and VoiceOver button
/// semantics for free, rather than each screen wiring its own
/// `UITapGestureRecognizer` and getting those for free nowhere.
///
/// Leads with a generic per-category icon (see `CategoryIcon`) rather than
/// a user photo — Item Editor never captures one, and the mockup's own
/// Add Manually form doesn't collect one either.
final class ItemRowView: UIControl {

    /// Exposed so a `.touchUpInside` target can read back which item this
    /// row represents (`sender.item`) rather than every call site having to
    /// keep its own item-per-row lookup.
    private(set) var item: Item

    private let categoryIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = AppTheme.Color.primary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.Font.headline()
        label.textColor = AppTheme.Color.textPrimary
        label.numberOfLines = 1
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.Font.caption()
        label.textColor = AppTheme.Color.textSecondary
        label.numberOfLines = 1
        return label
    }()

    private let statusLabel: InsetLabel = {
        let label = InsetLabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.textInsets = AppTheme.Metrics.chipTextInsets
        return label
    }()

    private let chevron: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        imageView.tintColor = AppTheme.Color.textSecondary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    init(item: Item) {
        self.item = item
        super.init(frame: .zero)
        backgroundColor = AppTheme.Color.cardBackground
        layer.cornerRadius = AppTheme.Metrics.cardCornerRadius
        configure(with: item)
        layout()
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Standard "dim while pressed" feedback, matching how `UIButton`
    /// behaves by default — free once this became a `UIControl`.
    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1.0 }
    }

    private func configure(with item: Item) {
        categoryIconView.image = UIImage(systemName: CategoryIcon.symbolName(for: item.category))
        nameLabel.text = item.name

        let quantityText = ItemRowView.quantityFormatter.string(from: NSNumber(value: item.quantity)) ?? "\(item.quantity)"
        let expiryText = ExpiryStatusCalculator.displayText(for: item.expiryDate)
        detailLabel.text = "\(item.category) · \(quantityText) \(item.unit.displayName) · \(expiryText)"

        let status = item.status()
        statusLabel.text = status.label
        statusLabel.backgroundColor = status.color
        statusLabel.accessibilityLabel = status.label

        accessibilityLabel = "\(item.name), \(item.category), \(status.label)"
        accessibilityHint = "Opens item details"
    }

    private func layout() {
        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        // Arranged subviews of a UIControl don't receive touches by default
        // interference-free, but they also shouldn't themselves intercept
        // the row's own touch handling — none of them are interactive, so
        // this is just defensive rather than fixing an observed bug.
        textStack.isUserInteractionEnabled = false

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        chevron.translatesAutoresizingMaskIntoConstraints = false

        categoryIconView.translatesAutoresizingMaskIntoConstraints = false
        let contentStack = UIStackView(arrangedSubviews: [categoryIconView, textStack, statusLabel, chevron])
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isUserInteractionEnabled = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            statusLabel.heightAnchor.constraint(equalToConstant: 22),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16),
            categoryIconView.widthAnchor.constraint(equalToConstant: 28),
            categoryIconView.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Keeps the status chip and chevron from being compressed before
        // the name/detail text truncates — the text is the element that
        // should give way first on a narrow screen or long item name.
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        categoryIconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
