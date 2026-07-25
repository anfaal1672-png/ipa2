import UIKit

/// `UITextView` subclass that draws the line-number gutter, the current line
/// highlight and indentation guides, and provides code-aware editing helpers.
final class CodeTextView: UITextView {

    var theme: EditorTheme = Themes.midnight { didSet { applyTheme(); setNeedsDisplay() } }
    var showLineNumbers = true { didSet { updateInsets(); setNeedsDisplay() } }
    var highlightCurrentLine = true { didSet { setNeedsDisplay() } }
    var showIndentGuides = true { didSet { setNeedsDisplay() } }
    var indentWidth: Int = 4
    var codeFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular) {
        didSet { updateInsets(); setNeedsDisplay() }
    }

    private(set) var gutterWidth: CGFloat = 44

    // MARK: - Init

    init(textStorage: CodeTextStorage) {
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)
        super.init(frame: .zero, textContainer: container)

        isEditable = true
        isSelectable = true
        alwaysBounceVertical = true
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        keyboardType = .asciiCapable
        contentInsetAdjustmentBehavior = .never
        textContainer.lineFragmentPadding = 4
        updateInsets()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Pinch to change the text size

    /// Called with the new point size while the user pinches.
    var onFontSizeChange: ((CGFloat) -> Void)?

    private var pinchStartSize: CGFloat = 14
    private weak var pinchRecognizer: UIPinchGestureRecognizer?

    func setPinchZoomEnabled(_ enabled: Bool) {
        if enabled, pinchRecognizer == nil {
            let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            addGestureRecognizer(recognizer)
            pinchRecognizer = recognizer
        } else if !enabled, let recognizer = pinchRecognizer {
            removeGestureRecognizer(recognizer)
            pinchRecognizer = nil
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStartSize = codeFont.pointSize
        case .changed:
            let proposed = (pinchStartSize * recognizer.scale).rounded()
            let clamped = min(30, max(9, proposed))
            if clamped != codeFont.pointSize {
                onFontSizeChange?(clamped)
            }
        default:
            break
        }
    }

    private func applyTheme() {
        backgroundColor = theme.background
        tintColor = theme.caret
        indicatorStyle = theme.isDark ? .white : .black
        keyboardAppearance = theme.isDark ? .dark : .light
    }

    func updateInsets() {
        let digits = max(2, String(max(1, numberOfLines)).count)
        gutterWidth = showLineNumbers
            ? ceil(codeFont.pointSize * 0.62) * CGFloat(digits) + 18
            : 6
        textContainerInset = UIEdgeInsets(top: 8, left: gutterWidth, bottom: 120, right: 8)
    }

    private(set) var numberOfLines: Int = 1

    func recomputeLineCount() {
        let ns = text as NSString
        var count = 1
        var index = 0
        while index < ns.length {
            let r = ns.range(of: "\n", options: [], range: NSRange(location: index, length: ns.length - index))
            if r.location == NSNotFound { break }
            count += 1
            index = r.location + 1
        }
        if count != numberOfLines {
            numberOfLines = count
            updateInsets()
        }
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let layoutManager = textContainer.layoutManager else {
            super.draw(rect)
            return
        }

        let originX = bounds.origin.x   // keeps the gutter pinned when scrolling sideways
        let selectedRange = self.selectedRange
        let ns = text as NSString
        let currentLineRange = ns.length > 0
            ? ns.paragraphRange(for: NSRange(location: min(selectedRange.location, ns.length), length: 0))
            : NSRange(location: 0, length: 0)

        // current line highlight
        if highlightCurrentLine && isFirstResponder {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: currentLineRange, actualCharacterRange: nil)
            context.setFillColor(theme.currentLine.cgColor)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                let r = CGRect(x: originX,
                               y: usedRect.origin.y + self.textContainerInset.top,
                               width: self.bounds.width,
                               height: usedRect.height)
                context.fill(r)
            }
        }

        // indentation guides
        if showIndentGuides {
            drawIndentGuides(context: context, layoutManager: layoutManager, rect: rect)
        }

        super.draw(rect)

        // gutter
        guard showLineNumbers else { return }
        context.setFillColor(theme.gutterBackground.cgColor)
        context.fill(CGRect(x: originX, y: rect.minY, width: gutterWidth - 6, height: rect.height))
        context.setStrokeColor(theme.indentGuide.cgColor)
        context.setLineWidth(1 / UIScreen.main.scale)
        context.move(to: CGPoint(x: originX + gutterWidth - 6, y: rect.minY))
        context.addLine(to: CGPoint(x: originX + gutterWidth - 6, y: rect.maxY))
        context.strokePath()

        let numberFont = UIFont.monospacedDigitSystemFont(ofSize: max(9, codeFont.pointSize * 0.82), weight: .regular)
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: bounds, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        var lineNumber = countLines(upTo: visibleCharRange.location, in: ns)
        var index = visibleCharRange.location
        while index < NSMaxRange(visibleCharRange) || (index == 0 && ns.length == 0) {
            let lineRange = ns.length > 0 ? ns.paragraphRange(for: NSRange(location: index, length: 0))
                                          : NSRange(location: 0, length: 0)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var fragment = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            fragment.origin.y += textContainerInset.top

            let isCurrent = NSLocationInRange(selectedRange.location, lineRange)
                || selectedRange.location == NSMaxRange(lineRange)
            let color = isCurrent ? theme.gutterActiveForeground : theme.gutterForeground
            let attributes: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: color
            ]
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: originX + gutterWidth - 12 - size.width,
                                   y: fragment.origin.y + (fragment.height - size.height) / 2),
                       withAttributes: attributes)

            lineNumber += 1
            let next = NSMaxRange(lineRange)
            if next <= index { break }
            index = next
            if ns.length == 0 { break }
        }
    }

    private func countLines(upTo location: Int, in ns: NSString) -> Int {
        guard location > 0 else { return 1 }
        var count = 1
        var index = 0
        while index < location {
            let r = ns.range(of: "\n", options: [], range: NSRange(location: index, length: location - index))
            if r.location == NSNotFound { break }
            count += 1
            index = r.location + 1
        }
        return count
    }

    private func drawIndentGuides(context: CGContext, layoutManager: NSLayoutManager, rect: CGRect) {
        let ns = text as NSString
        guard ns.length > 0 else { return }
        let charWidth = ("0" as NSString).size(withAttributes: [.font: codeFont]).width
        guard charWidth > 0 else { return }

        context.setStrokeColor(theme.indentGuide.cgColor)
        context.setLineWidth(1 / UIScreen.main.scale)

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: bounds, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        var index = visibleCharRange.location

        while index < NSMaxRange(visibleCharRange) {
            let lineRange = ns.paragraphRange(for: NSRange(location: index, length: 0))
            var indent = 0
            var i = lineRange.location
            while i < NSMaxRange(lineRange) {
                let c = ns.character(at: i)
                if c == 0x20 { indent += 1 }
                else if c == 0x09 { indent += indentWidth }
                else { break }
                i += 1
            }
            let levels = indent / max(1, indentWidth)
            if levels > 0 {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                var fragment = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
                fragment.origin.y += textContainerInset.top
                for level in 1...levels {
                    let x = textContainerInset.left + textContainer.lineFragmentPadding
                        + CGFloat(level - 1) * CGFloat(indentWidth) * charWidth
                    context.move(to: CGPoint(x: x, y: fragment.minY))
                    context.addLine(to: CGPoint(x: x, y: fragment.maxY))
                }
            }
            let next = NSMaxRange(lineRange)
            if next <= index { break }
            index = next
        }
        context.strokePath()
    }

    // MARK: - Selection / caret helpers

    override var selectedTextRange: UITextRange? {
        didSet { setNeedsDisplay() }
    }

    /// Character range of the line containing the caret.
    var currentLineRange: NSRange {
        let ns = text as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        return ns.paragraphRange(for: NSRange(location: min(selectedRange.location, ns.length), length: 0))
    }

    /// 1-based caret position, used by the status bar.
    var caretPosition: (line: Int, column: Int) {
        let ns = text as NSString
        let location = min(selectedRange.location, ns.length)
        let line = countLines(upTo: location, in: ns)
        let lineRange = ns.length > 0 ? ns.paragraphRange(for: NSRange(location: location, length: 0))
                                      : NSRange(location: 0, length: 0)
        return (line, location - lineRange.location + 1)
    }
}
