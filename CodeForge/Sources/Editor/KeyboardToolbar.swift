import UIKit

protocol KeyboardToolbarDelegate: AnyObject {
    func toolbarDidInsert(_ text: String)
    func toolbarDidTapTab()
    func toolbarDidTapOutdent()
    func toolbarDidTapUndo()
    func toolbarDidTapRedo()
    func toolbarDidMoveCaret(by offset: Int)
    func toolbarDidTapDismiss()
}

/// The extra key row that sits above the system keyboard. The middle section is
/// language-aware: editing Python offers `:` and quotes, shell offers `$` and
/// pipes, and so on.
final class KeyboardToolbar: UIInputView {

    weak var delegate: KeyboardToolbarDelegate?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var theme: EditorTheme = Themes.midnight

    init(theme: EditorTheme) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 46), inputViewStyle: .keyboard)
        self.theme = theme
        allowsSelfSizing = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 46).isActive = true

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(language: LanguageDefinition, theme: EditorTheme) {
        self.theme = theme
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        addSymbolButton(system: "arrow.right.to.line", action: #selector(tapTab))
        addSymbolButton(system: "arrow.left.to.line", action: #selector(tapOutdent))

        var symbols = language.keyboardExtras
        if symbols.isEmpty {
            symbols = ["{", "}", "(", ")", "[", "]", "<", ">", "=", "+", "-", "*", "/", "\"", "'", ";", ":", "_", "#", "&", "|", "!", "?", ".", ",", "$", "%", "@", "\\", "`", "~", "^"]
        } else {
            symbols += ["=", "+", "-", "%", "!", "?", "\\", "^", "~", "<", ">", ","]
        }
        for symbol in symbols {
            addTextButton(symbol)
        }

        addSymbolButton(system: "arrow.left", action: #selector(moveLeft))
        addSymbolButton(system: "arrow.right", action: #selector(moveRight))
        addSymbolButton(system: "arrow.uturn.backward", action: #selector(tapUndo))
        addSymbolButton(system: "arrow.uturn.forward", action: #selector(tapRedo))
        addSymbolButton(system: "keyboard.chevron.compact.down", action: #selector(tapDismiss))
    }

    private func makeButtonBase() -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = theme.isDark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.07)
        button.tintColor = theme.isDark ? .white : .black
        button.setTitleColor(theme.isDark ? .white : .black, for: .normal)
        button.layer.cornerRadius = 7
        button.layer.cornerCurve = .continuous
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        return button
    }

    private func addTextButton(_ symbol: String) {
        let button = makeButtonBase()
        button.setTitle(symbol, for: .normal)
        button.titleLabel?.font = .monospacedSystemFont(ofSize: 17, weight: .medium)
        button.accessibilityLabel = symbol
        button.addTarget(self, action: #selector(tapSymbol(_:)), for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    private func addSymbolButton(system name: String, action: Selector) {
        let button = makeButtonBase()
        button.setImage(UIImage(systemName: name), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    // MARK: - Actions

    @objc private func tapSymbol(_ sender: UIButton) {
        guard let symbol = sender.currentTitle else { return }
        UIDevice.current.playInputClick()
        delegate?.toolbarDidInsert(symbol)
    }

    @objc private func tapTab() { delegate?.toolbarDidTapTab() }
    @objc private func tapOutdent() { delegate?.toolbarDidTapOutdent() }
    @objc private func tapUndo() { delegate?.toolbarDidTapUndo() }
    @objc private func tapRedo() { delegate?.toolbarDidTapRedo() }
    @objc private func moveLeft() { delegate?.toolbarDidMoveCaret(by: -1) }
    @objc private func moveRight() { delegate?.toolbarDidMoveCaret(by: 1) }
    @objc private func tapDismiss() { delegate?.toolbarDidTapDismiss() }
}

extension KeyboardToolbar: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
