import UIKit

/// Reusable row for displaying an `Item` — the "common item row" from the
/// design spec (image/name/category/expiry/status/chevron), used by both
/// the Items list and Home's "Expiring Soon" section so the two screens
/// can't drift apart on how a row looks. Matches the `Shared/ItemCell` slot
/// named in the original project structure notes.
///
/// No thumbnail yet — Item Editor doesn't capture a photo in this pass (see
/// the accompanying review's "not yet built" list), so the leading image
/// well simply isn't shown rather than rendering an empty placeholder box.
final class ItemRowView: UIView {

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

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()

    private let chevron: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        imageView.tintColor = AppTheme.Color.textSecondary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    init(item: Item) {
        super.init(frame: .zero)
        backgroundColor = AppTheme.Color.cardBackground
        layer.cornerRadius = AppTheme.Metrics.cardCornerRadius
        configure(with: item)
        layout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure(with item: Item) {
        nameLabel.text = item.name

        let quantityText = ItemRowView.quantityFormatter.string(from: NSNumber(value: item.quantity)) ?? "\(item.quantity)"
        let expiryText = ExpiryStatusCalculator.displayText(for: item.expiryDate)
        detailLabel.text = "\(item.category) · \(quantityText) \(item.unit.displayName) · \(expiryText)"

        let status = item.status()
        statusLabel.text = "  \(status.label)  "
        statusLabel.backgroundColor = status.color
        statusLabel.accessibilityLabel = status.label
    }

    private func layout() {
        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [textStack, statusLabel, chevron])
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            statusLabel.heightAnchor.constraint(equalToConstant: 22),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Keeps the status chip and chevron from being compressed before
        // the name/detail text truncates — the text is the element that
        // should give way first on a narrow screen or long item name.
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
