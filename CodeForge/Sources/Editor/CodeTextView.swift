import UIKit

/// The line-number column.
///
/// It is a separate view pinned to the viewport rather than something drawn
/// inside the text view, because a gutter drawn in the text view has to be
/// invalidated on every scroll event — and invalidating a text view that holds
/// a large document is exactly what makes scrolling stutter. This view is
/// roughly 44pt wide, so repainting it per frame costs almost nothing.
final class GutterView: UIView {

    weak var textView: CodeTextView?
    var theme: EditorTheme = Themes.midnight { didSet { setNeedsDisplay() } }
    var numberFont: UIFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let textView,
              let layoutManager = textView.textContainer.layoutManager,
              let context = UIGraphicsGetCurrentContext() else { return }

        context.setFillColor(theme.gutterBackground.cgColor)
        context.fill(rect)
        context.setStrokeColor(theme.indentGuide.cgColor)
        context.setLineWidth(1 / UIScreen.main.scale)
        context.move(to: CGPoint(x: bounds.maxX - 0.5, y: rect.minY))
        context.addLine(to: CGPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        context.strokePath()

        let storage = textView.codeStorage
        let container = textView.textContainer
        let offsetY = textView.contentOffset.y - textView.textContainerInset.top
        let selection = textView.selectedRange

        // One pass over the visible line fragments; the line number of the
        // first one comes from the storage's index, and the rest follow.
        var visibleRect = textView.bounds
        visibleRect.origin.y -= textView.textContainerInset.top
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        var lineNumber = storage.lineNumber(at: charRange.location)
        var lastLineStart = -1

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, fragmentGlyphRange, _ in
            let fragmentCharRange = layoutManager.characterRange(forGlyphRange: fragmentGlyphRange,
                                                                 actualGlyphRange: nil)
            let lineStart = storage.startOfLine(storage.lineNumber(at: fragmentCharRange.location))

            // A wrapped line produces several fragments; only the first one
            // carries the number.
            if lineStart == lastLineStart { return }
            if lastLineStart != -1 { lineNumber += 1 }
            lastLineStart = lineStart

            let y = usedRect.origin.y - offsetY
            guard y > -usedRect.height, y < self.bounds.height else { return }

            let isCurrent = NSLocationInRange(selection.location,
                                              NSRange(location: lineStart,
                                                      length: max(1, NSMaxRange(fragmentCharRange) - lineStart)))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: self.numberFont,
                .foregroundColor: isCurrent ? self.theme.gutterActiveForeground : self.theme.gutterForeground
            ]
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: self.bounds.width - 10 - size.width,
                                   y: y + (usedRect.height - size.height) / 2),
                       withAttributes: attributes)
        }
    }
}

/// `UITextView` subclass with a code-editor chrome: gutter, current-line
/// highlight and indentation guides.
///
/// Everything is derived from the storage's line index rather than by scanning
/// the text, so cost tracks what is on screen, not the length of the file.
final class CodeTextView: UITextView {

    // Every one of these is assigned on each SwiftUI update — which happens per
    // keystroke — so they all check for an actual change first. Without the
    // guards, typing repainted the whole visible text view on every character.
    var theme: EditorTheme = Themes.midnight {
        didSet {
            guard theme.id != oldValue.id else { return }
            applyTheme()
            gutter.theme = theme
            setNeedsDisplay()
        }
    }
    var showLineNumbers = true {
        didSet {
            guard showLineNumbers != oldValue else { return }
            gutter.isHidden = !showLineNumbers
            updateInsets()
            setNeedsDisplay()
        }
    }
    var highlightCurrentLine = true {
        didSet { if highlightCurrentLine != oldValue { setNeedsDisplay() } }
    }
    var showIndentGuides = true {
        didSet { if showIndentGuides != oldValue { setNeedsDisplay() } }
    }
    var indentWidth: Int = 4
    var codeFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular) {
        didSet {
            guard codeFont != oldValue else { return }
            gutter.numberFont = .monospacedDigitSystemFont(ofSize: max(9, codeFont.pointSize * 0.82),
                                                           weight: .regular)
            updateInsets()
            setNeedsDisplay()
        }
    }

    private(set) var gutterWidth: CGFloat = 44
    let codeStorage: CodeTextStorage
    private let gutter = GutterView()

    // MARK: - Init

    init(textStorage: CodeTextStorage, nonContiguousLayout: Bool = true) {
        self.codeStorage = textStorage
        let layoutManager = NSLayoutManager()
        // Non-contiguous layout is what keeps opening and scrolling a large
        // file fast: TextKit lays out what is visible instead of everything.
        // Overridable so the self test can measure both settings.
        layoutManager.allowsNonContiguousLayout = nonContiguousLayout
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

        gutter.textView = self
        gutter.theme = theme
        addSubview(gutter)

        textStorage.visibleRangeProvider = { [weak self] in
            self?.visibleCharacterRange() ?? NSRange(location: 0, length: 0)
        }

        updateInsets()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func applyTheme() {
        backgroundColor = theme.background
        tintColor = theme.caret
        indicatorStyle = theme.isDark ? .white : .black
        keyboardAppearance = theme.isDark ? .dark : .light
    }

    // MARK: - Pinch to change the text size

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

    // MARK: - Layout

    func updateInsets() {
        let digits = max(2, String(max(1, codeStorage.lineCount)).count)
        gutterWidth = showLineNumbers
            ? ceil(codeFont.pointSize * 0.62) * CGFloat(digits) + 18
            : 6
        let inset = UIEdgeInsets(top: 8, left: gutterWidth, bottom: 120, right: 8)
        if textContainerInset != inset { textContainerInset = inset }
        positionGutter()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        positionGutter()
    }

    private func positionGutter() {
        guard showLineNumbers else { return }
        let frame = CGRect(x: contentOffset.x, y: contentOffset.y,
                           width: gutterWidth - 6, height: bounds.height)
        if gutter.frame != frame { gutter.frame = frame }
        // Reordering subviews invalidates the text view's layout, and this runs
        // on every scroll event — so only when it is actually out of order.
        if subviews.last !== gutter { bringSubviewToFront(gutter) }
    }

    /// Called from the scroll delegate. Only the gutter is repainted — the
    /// text itself scrolls without any invalidation.
    func viewportDidChange() {
        positionGutter()
        gutter.setNeedsDisplay()
        requestVisibleHighlight()
    }

    func refreshGutter() {
        updateInsets()
        gutter.setNeedsDisplay()
    }

    var numberOfLines: Int { codeStorage.lineCount }

    /// The document as `NSString` without the whole-buffer copy that
    /// `UITextView.text` performs. Every hot path uses this.
    var textNS: NSString { codeStorage.nsString }

    /// Characters currently laid out inside the viewport, with a screen of
    /// slack either side.
    func visibleCharacterRange() -> NSRange {
        guard let layoutManager = textContainer.layoutManager else {
            return NSRange(location: 0, length: 0)
        }
        var rect = bounds
        rect.origin.y -= textContainerInset.top
        rect = rect.insetBy(dx: 0, dy: -rect.height)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }

    private var highlightWorkItem: DispatchWorkItem?

    /// Debounced request to colour whatever scrolled into view.
    func requestVisibleHighlight() {
        highlightWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.codeStorage.highlightVisibleRegion()
        }
        highlightWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: work)
    }

    // MARK: - Drawing
    //
    // Only decorations that live in *content* coordinates are drawn here: they
    // scroll with the text, so scrolling needs no invalidation at all.

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let layoutManager = textContainer.layoutManager else {
            super.draw(rect)
            return
        }

        if highlightCurrentLine && isFirstResponder {
            let ns = textNS
            let currentLineRange = ns.length > 0
                ? ns.paragraphRange(for: NSRange(location: min(selectedRange.location, ns.length), length: 0))
                : NSRange(location: 0, length: 0)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: currentLineRange,
                                                      actualCharacterRange: nil)
            context.setFillColor(theme.currentLine.cgColor)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                context.fill(CGRect(x: self.bounds.origin.x,
                                    y: usedRect.origin.y + self.textContainerInset.top,
                                    width: max(self.bounds.width, self.contentSize.width),
                                    height: usedRect.height))
            }
        }

        if showIndentGuides {
            drawIndentGuides(context: context, layoutManager: layoutManager, dirtyRect: rect)
        }

        super.draw(rect)
    }

    private var cachedCharWidth: (font: UIFont, width: CGFloat)?

    /// Advance width of one character, measured once per font rather than on
    /// every repaint.
    private var characterWidth: CGFloat {
        if let cachedCharWidth, cachedCharWidth.font == codeFont { return cachedCharWidth.width }
        let width = ("0" as NSString).size(withAttributes: [.font: codeFont]).width
        cachedCharWidth = (codeFont, width)
        return width
    }

    private func drawIndentGuides(context: CGContext, layoutManager: NSLayoutManager, dirtyRect: CGRect) {
        let ns = textNS
        guard ns.length > 0 else { return }
        let charWidth = characterWidth
        guard charWidth > 0 else { return }

        context.setStrokeColor(theme.indentGuide.cgColor)
        context.setLineWidth(1 / UIScreen.main.scale)

        // Only the invalidated band is considered, so a partial redraw stays partial.
        var rect = dirtyRect
        rect.origin.y -= textContainerInset.top
        let glyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        var index = charRange.location

        while index < NSMaxRange(charRange) {
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
                let lineGlyphs = layoutManager.glyphRange(forCharacterRange: lineRange,
                                                          actualCharacterRange: nil)
                var fragment = layoutManager.lineFragmentUsedRect(forGlyphAt: lineGlyphs.location,
                                                                  effectiveRange: nil)
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
        didSet {
            gutter.setNeedsDisplay()
            invalidateCurrentLineHighlight()
        }
    }

    private var lastCurrentLineStart = -1

    /// Repaints the current-line highlight only when the caret actually moves to
    /// a different line, decided from the storage's line index — a binary
    /// search, no layout.
    ///
    /// Asking the layout manager for the line's rect here looked like a cheaper
    /// invalidation, but UIKit assigns this property from inside its own text
    /// processing: forcing glyph layout at that moment re-enters the layout
    /// manager, and with non-contiguous layout on a long document that meant
    /// laying out everything above the caret — from a setter that fires on every
    /// keystroke. Slow at best, and re-entrant at worst.
    private func invalidateCurrentLineHighlight() {
        guard highlightCurrentLine else {
            lastCurrentLineStart = -1
            return
        }
        let location = min(selectedRange.location, codeStorage.length)
        let start = codeStorage.startOfLine(codeStorage.lineNumber(at: location))
        guard start != lastCurrentLineStart else { return }
        lastCurrentLineStart = start
        // The highlight spans the full width, so only a move between lines
        // changes what is painted.
        setNeedsDisplay()
    }

    var currentLineRange: NSRange {
        let ns = textNS
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        return ns.paragraphRange(for: NSRange(location: min(selectedRange.location, ns.length), length: 0))
    }

    /// 1-based caret position, from the storage's index — O(log n).
    var caretPosition: (line: Int, column: Int) {
        let location = min(selectedRange.location, codeStorage.length)
        let line = codeStorage.lineNumber(at: location)
        return (line, location - codeStorage.startOfLine(line) + 1)
    }
}
