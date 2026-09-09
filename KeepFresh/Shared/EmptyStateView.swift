import UIKit

/// Reusable "nothing here yet" placeholder: SF Symbol, message, and an
/// optional call-to-action button. Used by Home today; Items/Notifications
/// reuse it once they exist rather than each rolling their own empty state.
final class EmptyStateView: UIView {

    var onActionTapped: (() -> Void)?

    init(symbolName: String, title: String, actionTitle: String?) {
        super.init(frame: .zero)

        let imageView = UIImageView(image: UIImage(systemName: symbolName))
        imageView.tintColor = AppTheme.Color.textSecondary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.Font.body()
        titleLabel.textColor = AppTheme.Color.textSecondary
        titleLabel.textAlignment = .center

        var arrangedSubviews: [UIView] = [imageView, titleLabel]

        if let actionTitle {
            var config = UIButton.Configuration.plain()
            config.title = actionTitle
            config.baseForegroundColor = AppTheme.Color.primary
            let button = UIButton(configuration: config)
            button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            arrangedSubviews.append(button)
        }

        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])

        backgroundColor = AppTheme.Color.cardBackground
        layer.cornerRadius = AppTheme.Metrics.cardCornerRadius
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func actionTapped() {
        onActionTapped?()
    }
}
