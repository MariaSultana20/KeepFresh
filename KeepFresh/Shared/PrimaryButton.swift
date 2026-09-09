import UIKit

/// The solid green "primary action" button used across the app (Save,
/// Continue, Sign In, etc.). Encapsulates the look so no screen redefines
/// it, and owns its own loading state — swapping its title for a spinner
/// when an action takes time, per Apple's guidance to give immediate
/// feedback on a tapped action rather than leaving the UI looking inert.
final class PrimaryButton: UIButton {

    private(set) var isLoadingState = false
    private var titleBeforeLoading: String?

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppTheme.Color.primary
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Font.headline()
            return outgoing
        }
        configuration = config

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true

        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        configurationUpdateHandler = { [weak self] button in
            let isDisabledButNotLoading = button.state == .disabled && self?.isLoadingState != true
            button.alpha = isDisabledButNotLoading ? 0.5 : 1.0
        }
    }

    /// Shows a spinner in place of the title and disables interaction so
    /// the user can't double-submit while a sign-in/save call is in flight.
    func setLoading(_ isLoading: Bool) {
        guard isLoading != isLoadingState else { return }
        isLoadingState = isLoading
        isEnabled = !isLoading

        if isLoading {
            titleBeforeLoading = configuration?.title
            configuration?.title = ""
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
            configuration?.title = titleBeforeLoading
        }
    }
}
