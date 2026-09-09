import UIKit

/// An outlined "Continue with X" button used for third-party sign-in
/// options that aren't the native `ASAuthorizationAppleIDButton` (which
/// Apple requires be rendered with its own control, not a custom look-alike).
final class SocialSignInButton: UIButton {

    convenience init(title: String, symbolName: String) {
        self.init(frame: .zero)
        configure(title: title, symbolName: symbolName)
    }

    private func configure(title: String, symbolName: String) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = AppTheme.Color.textPrimary
        config.image = UIImage(systemName: symbolName)
        config.imagePadding = 10
        config.imagePlacement = .leading
        config.title = title
        config.background.strokeColor = AppTheme.Color.separator
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppTheme.Metrics.buttonCornerRadius
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Font.headline()
            return outgoing
        }
        configuration = config

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: AppTheme.Metrics.buttonHeight).isActive = true

        configurationUpdateHandler = { button in
            button.alpha = button.state == .disabled ? 0.5 : 1.0
        }
    }
}
