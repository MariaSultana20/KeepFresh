import Combine
import UIKit

/// Editable display name, per the hand-drawn flow's Profile -> Edit
/// Profile -> Save -> Profile loop. Pushed (not modal), matching the
/// flow diagram's push/pop notation and how Settings-style profile editing
/// conventionally behaves on iOS — Cancel/Save still live as explicit nav
/// bar buttons rather than relying on the back button, matching this
/// codebase's own Item Editor pattern for "leave without saving" clarity.
/// Avatar editing and email (read-only, belongs to the provider account
/// per implementation-plan.md §4) are out of scope for this pass.
final class EditProfileViewController: UIViewController {

    private let viewModel: EditProfileViewModel
    private var cancellables = Set<AnyCancellable>()
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Display Name"
        field.autocapitalizationType = .words
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.Color.inputBackground
        field.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        return field
    }()

    private let nameErrorLabel: UILabel = {
        let label = UILabel()
        label.textColor = AppTheme.Color.expired
        label.font = AppTheme.Font.caption()
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private lazy var saveBarButtonItem = UIBarButtonItem(
        title: "Save", style: .done, target: self, action: #selector(saveTapped)
    )
    private lazy var loadingBarButtonItem: UIBarButtonItem = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        return UIBarButtonItem(customView: indicator)
    }()

    init(viewModel: EditProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit Profile"
        view.backgroundColor = AppTheme.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = saveBarButtonItem

        nameField.text = viewModel.initialDisplayName
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameField.delegate = self

        layout()
        bindViewModel()
        updateSaveButtonEnabled()
    }

    private func layout() {
        let nameLabel = UILabel()
        nameLabel.text = "Name"
        nameLabel.font = AppTheme.Font.caption()
        nameLabel.textColor = AppTheme.Color.textSecondary

        nameField.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true

        let stack = UIStackView(arrangedSubviews: [nameLabel, nameField, nameErrorLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                navigationItem.rightBarButtonItem = isLoading ? loadingBarButtonItem : saveBarButtonItem
                navigationItem.leftBarButtonItem?.isEnabled = !isLoading
                nameField.isEnabled = !isLoading
                if !isLoading { updateSaveButtonEnabled() }
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
        let alert = UIAlertController(title: "Couldn't Save", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func nameChanged() {
        updateSaveButtonEnabled()
    }

    private func updateSaveButtonEnabled() {
        saveBarButtonItem.isEnabled = viewModel.validate(displayName: nameField.text ?? "") == nil
    }

    @objc private func cancelTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        let name = nameField.text ?? ""
        if let error = viewModel.validate(displayName: name) {
            nameErrorLabel.text = error
            nameErrorLabel.isHidden = false
            feedbackGenerator.notificationOccurred(.error)
            return
        }
        nameErrorLabel.isHidden = true
        feedbackGenerator.prepare()
        viewModel.save(displayName: name)
    }
}

extension EditProfileViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
