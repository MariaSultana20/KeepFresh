import AuthenticationServices
import Combine
import Foundation
import UIKit

/// The sign-in screen: branding, Sign in with Apple / Google above an "or"
/// divider, then a manual email/password form — the layout Apple's own
/// first-party apps and HIG guidance for auth screens converge on. Apple is
/// required alongside any other third-party sign-in per App Store guideline
/// 4.8; Facebook was dropped from v1 to avoid its separate app-review
/// process (see the build plan for the full reasoning).
///
/// "Create Account" is a separate screen (`CreateAccountViewController`)
/// reached via the footer link, not a mode toggle on this one — matching
/// the standard "Sign In" vs "Create Account" split rather than a
/// segmented control.
final class SignInViewController: UIViewController {

    var onCreateAccountTapped: (() -> Void)?

    private let viewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // MARK: Views

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let markBackground: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Color.primary.withAlphaComponent(0.12)
        view.layer.cornerRadius = 24
        return view
    }()

    private let markLabel: UILabel = {
        let label = UILabel()
        label.text = "🥬"
        label.font = .systemFont(ofSize: 32)
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "KeepFresh"
        label.font = AppTheme.Font.title()
        label.textColor = AppTheme.Color.textPrimary
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Never let good things go to waste."
        label.font = AppTheme.Font.body()
        label.textColor = AppTheme.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// `.continue` matches the wording used by the Google/email options
    /// alongside it. Style (`.black`/`.white`) and `cornerRadius` are kept
    /// in sync with the current interface style by
    /// `updateAppleButtonStyleIfNeeded()` below, since the control doesn't
    /// re-theme itself for Dark Mode and its style can't change after
    /// init — Apple's own guidance is to recreate it.
    private var appleButton = ASAuthorizationAppleIDButton(type: .continue, style: .black)
    private var currentAppleButtonStyle: ASAuthorizationAppleIDButton.Style = .black
    private let socialStack = UIStackView()
    private let googleButton = SocialSignInButton(title: "Continue with Google", symbolName: "g.circle")

    private let emailField: UITextField = {
        let field = UITextField()
        field.placeholder = "Email Address"
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textContentType = .username
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.Color.inputBackground
        field.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        return field
    }()

    private let passwordField: PasswordField = {
        let field = PasswordField()
        field.placeholder = "Password"
        return field
    }()

    private let emailErrorLabel = SignInViewController.makeErrorLabel()
    private let passwordErrorLabel = SignInViewController.makeErrorLabel()

    private let signInButton: PrimaryButton = {
        let button = PrimaryButton()
        button.configuration?.title = "Sign In"
        return button
    }()

    private let forgotPasswordButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Forgot Password?"
        config.baseForegroundColor = AppTheme.Color.textSecondary
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Font.caption()
            return outgoing
        }
        let button = UIButton(configuration: config)
        return button
    }()

    private let createAccountButton: UIButton = {
        var config = UIButton.Configuration.plain()
        var title = AttributedString("Don't have an account? ")
        title.foregroundColor = AppTheme.Color.textSecondary
        var linkPart = AttributedString("Create Account")
        linkPart.foregroundColor = AppTheme.Color.primary
        title.append(linkPart)
        config.attributedTitle = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Font.body()
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.background
        layout()
        bindActions()
        bindViewModel()
        registerForKeyboardNotifications()

        emailField.delegate = self
        passwordField.delegate = self
        updateAppleButtonStyleIfNeeded()
    }

    // MARK: Layout

    private func layout() {
        markBackground.translatesAutoresizingMaskIntoConstraints = false
        markLabel.translatesAutoresizingMaskIntoConstraints = false
        markBackground.addSubview(markLabel)

        let headerStack = UIStackView(arrangedSubviews: [markBackground, titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.setCustomSpacing(16, after: markBackground)

        socialStack.axis = .vertical
        socialStack.spacing = AppTheme.Metrics.stackSpacing
        socialStack.addArrangedSubview(appleButton)
        socialStack.addArrangedSubview(googleButton)
        appleButton.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true
        appleButton.cornerRadius = AppTheme.Metrics.buttonCornerRadius

        let emailFieldStack = UIStackView(arrangedSubviews: [emailField, emailErrorLabel])
        emailFieldStack.axis = .vertical
        emailFieldStack.spacing = 4

        let passwordFieldStack = UIStackView(arrangedSubviews: [passwordField, passwordErrorLabel])
        passwordFieldStack.axis = .vertical
        passwordFieldStack.spacing = 4

        let formStack = UIStackView(arrangedSubviews: [emailFieldStack, passwordFieldStack, signInButton, forgotPasswordButton])
        formStack.axis = .vertical
        formStack.spacing = 12
        formStack.alignment = .fill
        formStack.setCustomSpacing(20, after: passwordFieldStack)
        formStack.setCustomSpacing(12, after: signInButton)

        [emailField, passwordField].forEach {
            $0.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true
        }
        // formStack's alignment is .fill, so this stretches full-width like
        // its siblings; UIButton centers its own title within that width by
        // default, which reads as a centered link under the Sign In button.
        forgotPasswordButton.contentHorizontalAlignment = .center
        // Its caption-sized text alone renders well under 44pt tall — HIG's
        // minimum tappable height — so pad the hit area without changing
        // how big the text looks.
        forgotPasswordButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let contentStack = UIStackView(arrangedSubviews: [
            headerStack, socialStack, DividerView(), formStack,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 28
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)
        view.addSubview(createAccountButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: createAccountButton.topAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            // Branding ~40-60pt below the status bar/safe area, not
            // vertically centered — the form below needs the rest of the
            // screen, and shouldn't jump around as the keyboard appears.
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),

            markBackground.widthAnchor.constraint(equalToConstant: 64),
            markBackground.heightAnchor.constraint(equalToConstant: 64),
            markLabel.centerXAnchor.constraint(equalTo: markBackground.centerXAnchor),
            markLabel.centerYAnchor.constraint(equalTo: markBackground.centerYAnchor),

            createAccountButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            createAccountButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            createAccountButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            createAccountButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        [emailErrorLabel, passwordErrorLabel].forEach { $0.isHidden = true }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppleButtonStyleIfNeeded()
    }

    /// `ASAuthorizationAppleIDButton`'s style can only be set at init and the
    /// control doesn't automatically re-theme for Dark Mode, so this swaps in
    /// a freshly-styled instance in the same stack position whenever the
    /// interface style changes.
    private func updateAppleButtonStyleIfNeeded() {
        let desiredStyle: ASAuthorizationAppleIDButton.Style = traitCollection.userInterfaceStyle == .dark ? .white : .black
        guard desiredStyle != currentAppleButtonStyle else { return }
        currentAppleButtonStyle = desiredStyle

        let replacement = ASAuthorizationAppleIDButton(type: .continue, style: desiredStyle)
        replacement.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        replacement.translatesAutoresizingMaskIntoConstraints = false
        replacement.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true
        replacement.addTarget(self, action: #selector(appleTapped), for: .touchUpInside)
        replacement.isEnabled = appleButton.isEnabled

        if let index = socialStack.arrangedSubviews.firstIndex(of: appleButton) {
            socialStack.removeArrangedSubview(appleButton)
            appleButton.removeFromSuperview()
            socialStack.insertArrangedSubview(replacement, at: index)
        }
        appleButton = replacement
    }

    private static func makeErrorLabel() -> UILabel {
        let label = UILabel()
        label.textColor = AppTheme.Color.expired
        label.font = AppTheme.Font.caption()
        label.numberOfLines = 0
        return label
    }

    // MARK: Actions

    private func bindActions() {
        appleButton.addTarget(self, action: #selector(appleTapped), for: .touchUpInside)
        googleButton.addTarget(self, action: #selector(googleTapped), for: .touchUpInside)
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
    }

    private func bindViewModel() {
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.signInButton.setLoading(isLoading)
                [self.appleButton, self.googleButton, self.forgotPasswordButton, self.createAccountButton].forEach {
                    $0.isEnabled = !isLoading
                }
                [self.emailField, self.passwordField].forEach { $0.isEnabled = !isLoading }
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.feedbackGenerator.notificationOccurred(.error)
                self?.presentError(message)
            }
            .store(in: &cancellables)

        viewModel.$passwordResetSent
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in
                self?.presentPasswordResetConfirmation()
            }
            .store(in: &cancellables)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentPasswordResetConfirmation() {
        let alert = UIAlertController(
            title: "Check Your Email",
            // Deliberately doesn't confirm whether the address is
            // registered — see AuthServiceProtocol.sendPasswordReset.
            message: "If an account exists for that email, we've sent a link to reset your password.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func appleTapped() {
        // TODO: once FirebaseAuthService lands, this should drive a real
        // ASAuthorizationController request and hand its credential to
        // Firebase Auth. For now it exercises the same loading/error path
        // through the mock service.
        feedbackGenerator.prepare()
        viewModel.signInWithApple()
    }

    @objc private func googleTapped() {
        // TODO: swap in the official "G" branding asset and the real
        // Google Sign-In SDK flow per Google's brand guidelines when this
        // is wired to FirebaseAuthService.
        feedbackGenerator.prepare()
        viewModel.signInWithGoogle()
    }

    @objc private func signInTapped() {
        attemptSignIn()
    }

    private func attemptSignIn() {
        view.endEditing(true)
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""

        let validation = viewModel.validateSignIn(email: email, password: password)
        showFieldErrors(validation)
        guard validation.isValid else {
            feedbackGenerator.notificationOccurred(.error)
            return
        }

        feedbackGenerator.prepare()
        viewModel.signIn(email: email, password: password)
    }

    private func showFieldErrors(_ validation: EmailFormValidation) {
        emailErrorLabel.text = validation.emailError
        emailErrorLabel.isHidden = validation.emailError == nil
        passwordErrorLabel.text = validation.passwordError
        passwordErrorLabel.isHidden = validation.passwordError == nil
    }

    @objc private func forgotPasswordTapped() {
        let alert = UIAlertController(
            title: "Reset Password",
            message: "Enter your email and we'll send you a link to reset your password.",
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] field in
            field.placeholder = "Email Address"
            field.keyboardType = .emailAddress
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.text = self?.emailField.text
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Link", style: .default) { [weak self, weak alert] _ in
            guard let email = alert?.textFields?.first?.text else { return }
            self?.viewModel.sendPasswordReset(email: email)
        })
        present(alert, animated: true)
    }

    @objc private func createAccountTapped() {
        onCreateAccountTapped?()
    }

    // MARK: Keyboard avoidance

    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }

        let isShowing = notification.name == UIResponder.keyboardWillShowNotification
        let overlap = isShowing ? view.convert(endFrame, from: nil).intersection(view.bounds).height : 0

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = overlap
            self.scrollView.verticalScrollIndicatorInsets.bottom = overlap
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else if textField === passwordField {
            attemptSignIn()
        }
        return true
    }
}
