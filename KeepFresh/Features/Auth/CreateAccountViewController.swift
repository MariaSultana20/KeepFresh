import Combine
import UIKit

/// Email/password account creation, reached from Sign In's footer link.
/// Kept as a separate screen rather than a mode toggle on Sign In — matches
/// the standard "Sign In" vs "Create Account" split rather than a
/// segmented control switching one form's meaning underneath the user.
final class CreateAccountViewController: UIViewController {

    private let viewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var keyboardHelper: KeyboardAvoidingScrollHelper?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

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
        field.textContentType = .newPassword
        field.placeholder = "Password"
        return field
    }()

    private let confirmPasswordField: PasswordField = {
        let field = PasswordField()
        field.textContentType = .newPassword
        field.placeholder = "Confirm Password"
        return field
    }()

    private let emailErrorLabel = CreateAccountViewController.makeErrorLabel()
    private let passwordErrorLabel = CreateAccountViewController.makeErrorLabel()
    private let confirmPasswordErrorLabel = CreateAccountViewController.makeErrorLabel()

    private let createAccountButton: PrimaryButton = {
        let button = PrimaryButton()
        button.configuration?.title = "Create Account"
        return button
    }()

    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "Create Account"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.background
        layout()
        bindActions()
        bindViewModel()
        keyboardHelper = KeyboardAvoidingScrollHelper(scrollView: scrollView, hostView: view)

        [emailField, passwordField, confirmPasswordField].forEach { $0.delegate = self }
    }

    private func layout() {
        let emailStack = labeledField(emailField, error: emailErrorLabel)
        let passwordStack = labeledField(passwordField, error: passwordErrorLabel)
        let confirmStack = labeledField(confirmPasswordField, error: confirmPasswordErrorLabel)

        [emailField, passwordField, confirmPasswordField].forEach {
            $0.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true
        }

        let formStack = UIStackView(arrangedSubviews: [emailStack, passwordStack, confirmStack, createAccountButton])
        formStack.axis = .vertical
        formStack.spacing = 12
        formStack.setCustomSpacing(24, after: confirmStack)
        formStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(formStack)

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

            formStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            formStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            formStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
        ])
    }

    private func labeledField(_ field: UIView, error: UILabel) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [field, error])
        stack.axis = .vertical
        stack.spacing = 4
        error.isHidden = true
        return stack
    }

    private static func makeErrorLabel() -> UILabel {
        let label = UILabel()
        label.textColor = AppTheme.Color.expired
        label.font = AppTheme.Font.caption()
        label.numberOfLines = 0
        return label
    }

    private func bindActions() {
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
    }

    private func bindViewModel() {
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.createAccountButton.setLoading(isLoading)
                [self.emailField, self.passwordField, self.confirmPasswordField].forEach { $0.isEnabled = !isLoading }
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
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Couldn't create account", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func createAccountTapped() {
        attemptCreateAccount()
    }

    private func attemptCreateAccount() {
        view.endEditing(true)
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""
        let confirmPassword = confirmPasswordField.text ?? ""

        let validation = viewModel.validateSignUp(email: email, password: password, confirmPassword: confirmPassword)
        emailErrorLabel.text = validation.emailError
        emailErrorLabel.isHidden = validation.emailError == nil
        passwordErrorLabel.text = validation.passwordError
        passwordErrorLabel.isHidden = validation.passwordError == nil
        confirmPasswordErrorLabel.text = validation.confirmPasswordError
        confirmPasswordErrorLabel.isHidden = validation.confirmPasswordError == nil

        guard validation.isValid else {
            feedbackGenerator.notificationOccurred(.error)
            return
        }

        feedbackGenerator.prepare()
        viewModel.signUp(email: email, password: password)
    }
}

extension CreateAccountViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else if textField === passwordField {
            confirmPasswordField.becomeFirstResponder()
        } else {
            attemptCreateAccount()
        }
        return true
    }
}
