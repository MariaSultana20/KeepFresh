import UIKit

/// Profile in its v1 shell: signed-in user's info and Sign Out. Editable
/// photo/display name, notification preferences, and the destructive
/// account-deletion flow are build plan commit 9.
final class ProfileViewController: UIViewController {

    var onSignOutTapped: (() -> Void)?

    private let user: AuthUser

    private let avatarView: UIView = {
        let container = UIView()
        container.backgroundColor = AppTheme.Color.cardBackground
        container.layer.cornerRadius = 40

        let imageView = UIImageView(image: UIImage(systemName: "person.fill"))
        imageView.tintColor = AppTheme.Color.textSecondary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 36),
            imageView.heightAnchor.constraint(equalToConstant: 36),
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 80),
        ])
        return container
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.text = user.displayName ?? "KeepFresh User"
        label.font = AppTheme.Font.title()
        label.textColor = AppTheme.Color.textPrimary
        label.textAlignment = .center
        return label
    }()

    private lazy var emailLabel: UILabel = {
        let label = UILabel()
        label.text = user.email
        label.font = AppTheme.Font.body()
        label.textColor = AppTheme.Color.textSecondary
        label.textAlignment = .center
        label.isHidden = user.email == nil
        return label
    }()

    /// Plain-style, red *text* only — not a filled red button. Sign Out
    /// isn't a destructive action (nothing is deleted, it's fully
    /// reversible), so it shouldn't carry the same filled-red treatment
    /// the real account-deletion button (commit 9) will need; this matches
    /// how Settings.app itself renders "Sign Out" (a plain row, red text,
    /// no filled background), reserving a solid destructive style for
    /// actions that actually are irreversible.
    private lazy var signOutButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Sign Out"
        configuration.baseForegroundColor = AppTheme.Color.expired
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Font.headline()
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        return button
    }()

    init(user: AuthUser) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        view.backgroundColor = AppTheme.Color.background
        layout()
    }

    private func layout() {
        let stack = UIStackView(arrangedSubviews: [avatarView, nameLabel, emailLabel, signOutButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(32, after: emailLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func signOutTapped() {
        onSignOutTapped?()
    }
}
