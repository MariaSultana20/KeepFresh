import UIKit

/// Wires the standard keyboard-avoidance behavior (inset a scroll view by
/// however much the keyboard overlaps it, restore the inset when the
/// keyboard hides) for any view controller whose form lives in a
/// `UIScrollView`.
///
/// Extracted so a third screen doesn't duplicate the ~20-line
/// `registerForKeyboardNotifications` / `keyboardWillChange` block that
/// `SignInViewController` and `CreateAccountViewController` each still carry
/// today — flagged as tech debt in
/// `claude/KeepFresh-App-Structure-Feature-Flow.md` §6: "worth pulling into
/// a small... reusable helper object before a third copy lands... three
/// copies is where duplicated logic starts silently drifting." Item Editor
/// is that third copy, so it uses this instead.
///
/// The two Auth screens are intentionally left as-is here — retrofitting
/// them is a separate, isolated change (swapping in a helper on an already
/// shipped, working screen carries its own small risk and deserves its own
/// review) rather than something to bundle into this feature commit.
@MainActor
final class KeyboardAvoidingScrollHelper: NSObject {

    private weak var scrollView: UIScrollView?
    private weak var hostView: UIView?

    /// - Parameters:
    ///   - scrollView: The scroll view to inset as the keyboard shows/hides.
    ///   - hostView: The view whose coordinate space the keyboard's end
    ///     frame is converted into — normally the owning view controller's
    ///     `view`.
    init(scrollView: UIScrollView, hostView: UIView) {
        self.scrollView = scrollView
        self.hostView = hostView
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let scrollView, let hostView,
              let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }

        let isShowing = notification.name == UIResponder.keyboardWillShowNotification
        let overlap = isShowing ? hostView.convert(endFrame, from: nil).intersection(hostView.bounds).height : 0

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        UIView.animate(withDuration: duration) {
            scrollView.contentInset.bottom = overlap
            scrollView.verticalScrollIndicatorInsets.bottom = overlap
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
