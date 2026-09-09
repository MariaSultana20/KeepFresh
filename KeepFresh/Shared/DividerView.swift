import UIKit

/// The "── or ──" rule used to separate social sign-in from the manual
/// email form. A plain `UILabel` wouldn't read as a divider on its own, and
/// two full-bleed lines either side of the word are the standard iOS pattern.
final class DividerView: UIView {

    init(text: String = "or") {
        super.init(frame: .zero)

        let leadingLine = makeLine()
        let trailingLine = makeLine()

        let label = UILabel()
        label.text = text
        label.font = AppTheme.Font.caption()
        label.textColor = AppTheme.Color.textSecondary

        let stack = UIStackView(arrangedSubviews: [leadingLine, label, trailingLine])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            leadingLine.heightAnchor.constraint(equalToConstant: 1),
            trailingLine.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeLine() -> UIView {
        let line = UIView()
        line.backgroundColor = AppTheme.Color.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }
}
