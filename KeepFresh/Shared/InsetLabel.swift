import UIKit

/// A `UILabel` that supports real content padding via `textInsets`.
///
/// `UILabel` has no built-in equivalent to `UIButton`'s content insets, so
/// the common workaround is padding the string itself with literal
/// leading/trailing spaces. That's the anti-pattern this type replaces: a space
/// glyph's width isn't a fixed point value (it scales with the font, so the
/// "padding" silently changes under Dynamic Type or Bold Text), and
/// VoiceOver reads the extra whitespace as part of the label's value
/// instead of a layout detail.
///
/// Used anywhere a label renders as a filled "chip"/"pill" — status badges
/// today (`ItemRowView`, `ItemDetailsViewController`), and anywhere else
/// that pattern shows up next, per this project's own convention of
/// factoring out UI behavior into `Shared/` the moment a second call site
/// needs it.
class InsetLabel: UILabel {

    var textInsets: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitSize = super.sizeThatFits(size)
        return CGSize(
            width: fitSize.width + textInsets.left + textInsets.right,
            height: fitSize.height + textInsets.top + textInsets.bottom
        )
    }
}
