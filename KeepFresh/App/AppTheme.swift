import UIKit

/// Central design tokens for KeepFresh.
///
/// Every screen should pull colors, spacing, and corner radii from here
/// rather than hard-coding literals — this is the single place the
/// "bright, minimal, traffic-light" visual language from the design spec
/// is defined. In particular, `ExpiryStatus` colors (see the data layer,
/// added when Items/Home get real data) must reuse `AppTheme.Color.*`
/// rather than restating the hex values.
enum AppTheme {

    enum Color {
        /// Primary action color — buttons, selected tab, accent.
        static let primary = UIColor(hex: 0x16A34A)
        /// "Expired" status color.
        static let expired = UIColor(hex: 0xFF3B30)
        /// "Expiring soon" status color.
        static let expiringSoon = UIColor(hex: 0xFF9500)
        /// "Good" status color (same hue as primary, kept distinct for clarity at call sites).
        static let good = primary

        // Dynamic system colors rather than fixed hex values, so screens
        // built from these tokens adapt to Dark Mode automatically. The
        // brand/status colors above stay constant in both appearances —
        // they carry meaning (traffic-light system) and already have
        // enough contrast against both a white and a dark background.
        static let background = UIColor.systemBackground
        static let cardBackground = UIColor.secondarySystemBackground
        static let inputBackground = UIColor.secondarySystemBackground
        static let textPrimary = UIColor.label
        static let textSecondary = UIColor.secondaryLabel
        static let separator = UIColor.separator
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 14
        static let buttonHeight: CGFloat = 52
        static let screenMargin: CGFloat = 20
        static let stackSpacing: CGFloat = 16
        /// Horizontal/vertical padding for a filled "chip"/"pill" label —
        /// see `InsetLabel`. Centralized here rather than restated at each
        /// call site, same as every other spacing value in this enum.
        static let chipTextInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    }

    enum Font {
        /// Returns a scaled font that grows with the user's preferred text
        /// size. Pass `maximumPointSize` to cap runaway growth on screens
        /// that show many items at once (e.g. table rows).
        static func title(maximumPointSize: CGFloat? = nil) -> UIFont {
            scaled(.systemFont(ofSize: 28, weight: .bold), textStyle: .title1, maximum: maximumPointSize)
        }
        static func headline(maximumPointSize: CGFloat? = nil) -> UIFont {
            scaled(.systemFont(ofSize: 17, weight: .semibold), textStyle: .headline, maximum: maximumPointSize)
        }
        static func body(maximumPointSize: CGFloat? = nil) -> UIFont {
            scaled(.systemFont(ofSize: 15, weight: .regular), textStyle: .body, maximum: maximumPointSize)
        }
        static func caption(maximumPointSize: CGFloat? = nil) -> UIFont {
            scaled(.systemFont(ofSize: 13, weight: .medium), textStyle: .caption1, maximum: maximumPointSize)
        }

        private static func scaled(_ font: UIFont, textStyle: UIFont.TextStyle, maximum: CGFloat?) -> UIFont {
            let metrics = UIFontMetrics(forTextStyle: textStyle)
            if let maximum {
                return metrics.scaledFont(for: font, maximumPointSize: maximum)
            }
            return metrics.scaledFont(for: font)
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
