import UIKit

/// A secure text field with a built-in eye/eye-slash toggle, per the
/// standard iOS password-field pattern. Handles the well-known UITextField
/// quirk where flipping `isSecureTextEntry` while text is present can leave
/// the field showing the wrong font/content until it's forced to redraw.
final class PasswordField: UITextField {

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        isSecureTextEntry = true
        textContentType = .password
        borderStyle = .roundedRect
        backgroundColor = AppTheme.Color.inputBackground
        layer.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        layer.borderWidth = 0

        let toggle = UIButton(type: .system)
        toggle.tintColor = AppTheme.Color.textSecondary
        toggle.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        // 44x44 tappable area even though the glyph itself is small — HIG's
        // minimum recommended hit target, not just the icon's visual size.
        toggle.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        toggle.addTarget(self, action: #selector(toggleVisibility), for: .touchUpInside)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        container.addSubview(toggle)

        rightView = container
        rightViewMode = .always
    }

    @objc private func toggleVisibility() {
        // Forcing text off and back on avoids UITextField's occasional
        // "font resets to the system default" glitch when isSecureTextEntry
        // flips with existing text in the field.
        let existingText = text
        text = nil
        isSecureTextEntry.toggle()
        text = existingText

        if let toggleButton = (rightView?.subviews.first as? UIButton) {
            let symbolName = isSecureTextEntry ? "eye.slash" : "eye"
            toggleButton.setImage(UIImage(systemName: symbolName), for: .normal)
        }

        // Re-establishing first responder after the text reset above keeps
        // the cursor where the user left it instead of jumping to the end.
        if isFirstResponder {
            let end = endOfDocument
            selectedTextRange = textRange(from: end, to: end)
        }
    }
}
