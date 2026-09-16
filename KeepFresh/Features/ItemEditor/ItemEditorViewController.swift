import Combine
import UIKit

/// The shared Add/Edit form for an `Item`, per the Build Plan's "one shared
/// view in two modes" spec. Presented modally (see `AddItemCoordinator`),
/// so it follows the standard iOS modal-form pattern — Cancel/Save in the
/// navigation bar rather than an in-content button — instead of the
/// full-screen `PrimaryButton` pattern the Auth screens use, since those
/// aren't presented as sheets.
///
/// Fields: name, category (free text with a preset-category picker),
/// quantity + unit, purchase date, expiry date (required; can't be in the
/// past for a new item), an optional note, and the reminder lead time.
/// No photo picker yet — see the accompanying review for why that's scoped
/// out of this pass — and no long-press/detail screen wiring, since those
/// belong to Items/Item Details (a separate, bigger commit).
final class ItemEditorViewController: UIViewController {

    private static let presetCategories = [
        "Dairy", "Bakery", "Beverages", "Pantry", "Snacks",
        "Frozen", "Cosmetics", "Medicine", "Household", "Other",
    ]
    private static let reminderOptions = [0, 1, 3, 7, 14, 30]

    private let viewModel: ItemEditorViewModel
    private var cancellables = Set<AnyCancellable>()
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var keyboardHelper: KeyboardAvoidingScrollHelper?

    private var selectedUnit: Item.Unit

    // MARK: Views

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Item Name"
        field.autocapitalizationType = .words
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.Color.inputBackground
        field.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        return field
    }()

    private let categoryField: UITextField = {
        let field = UITextField()
        field.placeholder = "Category (e.g. Dairy)"
        field.autocapitalizationType = .words
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.Color.inputBackground
        field.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        return field
    }()

    private let categoryPickerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        button.tintColor = AppTheme.Color.textSecondary
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        return button
    }()

    private let quantityField: UITextField = {
        let field = UITextField()
        field.placeholder = "Quantity"
        field.keyboardType = .decimalPad
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.Color.inputBackground
        field.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        field.text = "1"
        return field
    }()

    private lazy var unitButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = AppTheme.Color.textPrimary
        configuration.image = UIImage(systemName: "chevron.up.chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Font.body()
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.backgroundColor = AppTheme.Color.inputBackground
        button.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private let purchaseDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        return picker
    }()

    private let expiryDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        return picker
    }()

    private lazy var reminderControl = UISegmentedControl(
        items: ItemEditorViewController.reminderOptions.map { $0 == 0 ? "On day" : "\($0)d" }
    )

    private let noteField: UITextField = {
        let field = UITextField()
        field.placeholder = "Note (optional)"
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.Color.inputBackground
        field.layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        return field
    }()

    private let nameErrorLabel = ItemEditorViewController.makeErrorLabel()
    private let categoryErrorLabel = ItemEditorViewController.makeErrorLabel()
    private let quantityErrorLabel = ItemEditorViewController.makeErrorLabel()

    private lazy var saveBarButtonItem = UIBarButtonItem(
        title: viewModel.saveButtonTitle, style: .done, target: self, action: #selector(saveTapped)
    )
    private lazy var loadingBarButtonItem: UIBarButtonItem = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        return UIBarButtonItem(customView: indicator)
    }()

    init(viewModel: ItemEditorViewModel) {
        self.viewModel = viewModel
        self.selectedUnit = viewModel.initialUnit
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.navigationTitle
        view.backgroundColor = AppTheme.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = saveBarButtonItem

        populateInitialValues()
        layout()
        bindActions()
        bindViewModel()
        keyboardHelper = KeyboardAvoidingScrollHelper(scrollView: scrollView, hostView: view)

        [nameField, categoryField, quantityField, noteField].forEach { $0.delegate = self }
        updateUnitButton()
        updateSaveButtonEnabled()
    }

    private func populateInitialValues() {
        nameField.text = viewModel.initialName
        categoryField.text = viewModel.initialCategory
        quantityField.text = ItemEditorViewController.quantityText(for: viewModel.initialQuantity)
        purchaseDatePicker.date = viewModel.initialPurchaseDate
        expiryDatePicker.date = viewModel.initialExpiryDate
        expiryDatePicker.minimumDate = viewModel.minimumExpiryDate
        noteField.text = viewModel.initialNote

        if let index = ItemEditorViewController.reminderOptions.firstIndex(of: viewModel.initialReminderDaysBefore) {
            reminderControl.selectedSegmentIndex = index
        } else {
            reminderControl.selectedSegmentIndex = ItemEditorViewController.reminderOptions.firstIndex(of: 7) ?? 0
        }
    }

    // MARK: Layout

    private func layout() {
        let nameStack = UIStackView(arrangedSubviews: [makeFieldLabel("Name"), nameField, nameErrorLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 4

        categoryField.rightView = categoryPickerButton
        categoryField.rightViewMode = .always
        let categoryStack = UIStackView(arrangedSubviews: [makeFieldLabel("Category"), categoryField, categoryErrorLabel])
        categoryStack.axis = .vertical
        categoryStack.spacing = 4

        let quantityUnitRow = UIStackView(arrangedSubviews: [quantityField, unitButton])
        quantityUnitRow.axis = .horizontal
        quantityUnitRow.spacing = 12
        quantityUnitRow.distribution = .fill
        unitButton.setContentHuggingPriority(.required, for: .horizontal)
        let quantityStack = UIStackView(arrangedSubviews: [makeFieldLabel("Quantity"), quantityUnitRow, quantityErrorLabel])
        quantityStack.axis = .vertical
        quantityStack.spacing = 4

        let purchaseDateRow = UIStackView(arrangedSubviews: [makeFieldLabel("Purchased On"), UIView(), purchaseDatePicker])
        purchaseDateRow.axis = .horizontal
        purchaseDateRow.alignment = .center

        let expiryDateRow = UIStackView(arrangedSubviews: [makeFieldLabel("Expires On"), UIView(), expiryDatePicker])
        expiryDateRow.axis = .horizontal
        expiryDateRow.alignment = .center

        let noteStack = UIStackView(arrangedSubviews: [makeFieldLabel("Note"), noteField])
        noteStack.axis = .vertical
        noteStack.spacing = 4

        let reminderStack = UIStackView(arrangedSubviews: [makeFieldLabel("Remind Me Before"), reminderControl])
        reminderStack.axis = .vertical
        reminderStack.spacing = 8

        [nameField, categoryField, quantityField, noteField].forEach {
            $0.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true
        }

        let contentStack = UIStackView(arrangedSubviews: [
            nameStack, categoryStack, quantityStack, purchaseDateRow, expiryDateRow, reminderStack, noteStack,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
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

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Metrics.screenMargin),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Metrics.screenMargin),
        ])

        [nameErrorLabel, categoryErrorLabel, quantityErrorLabel].forEach { $0.isHidden = true }
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.Font.caption()
        label.textColor = AppTheme.Color.textSecondary
        return label
    }

    private static func makeErrorLabel() -> UILabel {
        let label = UILabel()
        label.textColor = AppTheme.Color.expired
        label.font = AppTheme.Font.caption()
        label.numberOfLines = 0
        return label
    }

    private static func quantityText(for value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    // MARK: Actions

    private func bindActions() {
        categoryPickerButton.addTarget(self, action: #selector(categoryPickerTapped), for: .touchUpInside)
        expiryDatePicker.addTarget(self, action: #selector(formValuesChanged), for: .valueChanged)
        [nameField, categoryField, quantityField].forEach {
            $0.addTarget(self, action: #selector(formValuesChanged), for: .editingChanged)
        }
    }

    private func bindViewModel() {
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.navigationItem.rightBarButtonItem = isLoading ? self.loadingBarButtonItem : self.saveBarButtonItem
                self.navigationItem.leftBarButtonItem?.isEnabled = !isLoading
                if !isLoading { self.updateSaveButtonEnabled() }
                [self.nameField, self.categoryField, self.quantityField, self.noteField].forEach { $0.isEnabled = !isLoading }
                [self.categoryPickerButton, self.unitButton, self.purchaseDatePicker, self.expiryDatePicker, self.reminderControl]
                    .forEach { $0.isEnabled = !isLoading }
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

    @objc private func cancelTapped() {
        viewModel.onCancel?()
    }

    @objc private func formValuesChanged() {
        updateSaveButtonEnabled()
    }

    private func updateSaveButtonEnabled() {
        let validation = currentValidation()
        saveBarButtonItem.isEnabled = validation.isValid
    }

    private func currentValidation() -> ItemFormValidation {
        viewModel.validate(
            name: nameField.text ?? "",
            category: categoryField.text ?? "",
            quantityText: quantityField.text ?? "",
            expiryDate: expiryDatePicker.date
        )
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        let validation = currentValidation()
        showFieldErrors(validation)
        guard validation.isValid else {
            feedbackGenerator.notificationOccurred(.error)
            return
        }

        feedbackGenerator.prepare()
        viewModel.save(
            name: nameField.text ?? "",
            category: categoryField.text ?? "",
            quantity: Double(quantityField.text ?? "") ?? 1,
            unit: selectedUnit,
            purchaseDate: purchaseDatePicker.date,
            expiryDate: expiryDatePicker.date,
            note: noteField.text ?? "",
            reminderDaysBefore: ItemEditorViewController.reminderOptions[reminderControl.selectedSegmentIndex]
        )
    }

    private func showFieldErrors(_ validation: ItemFormValidation) {
        nameErrorLabel.text = validation.nameError
        nameErrorLabel.isHidden = validation.nameError == nil
        categoryErrorLabel.text = validation.categoryError
        categoryErrorLabel.isHidden = validation.categoryError == nil
        quantityErrorLabel.text = validation.quantityError
        quantityErrorLabel.isHidden = validation.quantityError == nil
    }

    // MARK: Unit picker

    private func updateUnitButton() {
        unitButton.configuration?.title = selectedUnit.displayName
        unitButton.menu = UIMenu(children: Item.Unit.allCases.map { unit in
            UIAction(title: unit.displayName, state: unit == selectedUnit ? .on : .off) { [weak self] _ in
                self?.selectedUnit = unit
                self?.updateUnitButton()
            }
        })
    }

    // MARK: Category picker

    @objc private func categoryPickerTapped() {
        view.endEditing(true)
        let sheet = UIAlertController(title: "Category", message: nil, preferredStyle: .actionSheet)
        for category in ItemEditorViewController.presetCategories {
            sheet.addAction(UIAlertAction(title: category, style: .default) { [weak self] _ in
                self?.categoryChosen(category)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // iPad presents action sheets as a popover and needs an anchor, or
        // this crashes — full-screen phone presentation ignores it.
        sheet.popoverPresentationController?.sourceView = categoryPickerButton
        sheet.popoverPresentationController?.sourceRect = categoryPickerButton.bounds
        present(sheet, animated: true)
    }

    private func categoryChosen(_ category: String) {
        if category == "Other" {
            // Leave the field empty for free text rather than literally
            // filling in the word "Other" as the category name.
            categoryField.text = ""
            categoryField.becomeFirstResponder()
        } else {
            categoryField.text = category
        }
        updateSaveButtonEnabled()
    }
}

extension ItemEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameField {
            categoryField.becomeFirstResponder()
        } else if textField === categoryField {
            quantityField.becomeFirstResponder()
        } else if textField === quantityField {
            noteField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
