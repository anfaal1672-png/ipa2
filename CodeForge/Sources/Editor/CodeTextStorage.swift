import UIKit

/// `NSTextStorage` subclass that keeps syntax colouring in sync with edits.
///
/// Performance shape, because this is what decides whether a 1 MB file is
/// usable on a phone:
///
///  * a synchronous pass over the edited paragraphs so typing feels instant;
///  * an asynchronous pass over **the visible window only** for large
///    documents (small ones still get the whole file, which keeps multi-line
///    constructs exact where it is cheap to be exact);
///  * a line-start index maintained incrementally, so the gutter and the caret
///    readout are O(log n) instead of rescanning the document every frame.
final class CodeTextStorage: NSTextStorage {

    private let backing = NSMutableAttributedString()
    private let queue = DispatchQueue(label: "codeforge.highlighter", qos: .userInitiated)

    private var version: Int = 0
    private var pendingWorkItem: DispatchWorkItem?
    private var lastHighlightedWindow = NSRange(location: 0, length: 0)

    /// Documents at or below this size are highlighted in full: exact, and
    /// cheap enough that nobody notices.
    private let wholeDocumentLimit = 80_000
    /// How much text before the visible window is fed to the scanner so that a
    /// block comment or heredoc started off-screen is still recognised.
    private let contextWindow = 24_000
    /// Extra text highlighted past the visible window, so a flick of the
    /// scroll wheel does not reveal uncoloured text.
    private let visiblePadding = 6_000
    /// Above this, colouring is off unless the user insists — tokenising tens
    /// of megabytes on a phone is not worth the battery.
    private let hardLimit = 12_000_000

    /// Set by the text view; lets the storage colour what the user can see.
    var visibleRangeProvider: (() -> NSRange)?

    var language: LanguageDefinition = LanguageRegistry.plainText {
        didSet {
            guard language.id != oldValue.id else { return }
            scanner = SyntaxScanner(language: language)
            rehighlightAll()
        }
    }

    var theme: EditorTheme = Themes.midnight {
        didSet {
            guard theme.id != oldValue.id else { return }
            rehighlightAll()
        }
    }

    var font: UIFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular) {
        didSet {
            guard font != oldValue else { return }
            rehighlightAll()
        }
    }

    var syntaxHighlightingEnabled: Bool = true {
        didSet {
            guard syntaxHighlightingEnabled != oldValue else { return }
            rehighlightAll()
        }
    }

    private var scanner = SyntaxScanner(language: LanguageRegistry.plainText)

    /// True when the document is too big to colour in full, which the status
    /// bar surfaces so the user knows why the far end of a huge file is plain.
    var isUsingWindowedHighlighting: Bool { length > wholeDocumentLimit }

    // MARK: - Line index

    /// UTF-16 offset of the first character of every line. Maintained through
    /// `processEditing` so no code path has to rescan the document.
    private(set) var lineStarts: [Int] = [0]

    var lineCount: Int { lineStarts.count }

    /// 1-based line number containing `location`.
    func lineNumber(at location: Int) -> Int {
        guard location > 0 else { return 1 }
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= location { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }

    /// UTF-16 offset where the given 1-based line starts.
    func startOfLine(_ line: Int) -> Int {
        let index = max(0, min(lineStarts.count - 1, line - 1))
        return lineStarts[index]
    }

    private func rebuildLineIndex() {
        let ns = backing.string as NSString
        var starts: [Int] = [0]
        starts.reserveCapacity(ns.length / 30 + 8)
        starts.append(contentsOf: Self.newlineOffsets(in: ns,
                                                      range: NSRange(location: 0, length: ns.length)))
        lineStarts = starts
    }

    /// Offsets just past every newline in `range`.
    ///
    /// Copied out in blocks and scanned as raw UTF-16 rather than asked of
    /// `NSString.range(of:)` per line: on a multi-megabyte file the per-call
    /// search machinery dominates, and this is the pass that runs when a big
    /// file is opened or pasted into.
    private static func newlineOffsets(in ns: NSString, range: NSRange) -> [Int] {
        guard range.length > 0 else { return [] }
        var result: [Int] = []
        result.reserveCapacity(range.length / 30 + 4)

        let blockSize = 64 * 1024
        var buffer = [unichar](repeating: 0, count: min(blockSize, range.length))
        var offset = range.location
        let end = NSMaxRange(range)

        while offset < end {
            let count = min(blockSize, end - offset)
            buffer.withUnsafeMutableBufferPointer { pointer in
                guard let base = pointer.baseAddress else { return }
                ns.getCharacters(base, range: NSRange(location: offset, length: count))
                for index in 0..<count where base[index] == 0x0A {
                    result.append(offset + index + 1)
                }
            }
            offset += count
        }
        return result
    }

    /// Patches the index for one edit instead of rescanning: everything before
    /// the edit is untouched, the edited span is rescanned, and the tail is
    /// shifted by the length delta.
    private func updateLineIndex(editedRange: NSRange, delta: Int) {
        let ns = backing.string as NSString
        let oldEnd = editedRange.location + (editedRange.length - delta)

        guard editedRange.location >= 0, oldEnd >= editedRange.location,
              NSMaxRange(editedRange) <= ns.length else {
            rebuildLineIndex()
            return
        }

        // first line start strictly after the edit point
        var first = lineStarts.count
        var low = 0
        var high = lineStarts.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if lineStarts[mid] > editedRange.location {
                first = mid
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        // Line starts owned by the replaced span (old coordinates). A start with
        // the value oldEnd comes from the newline at oldEnd - 1, which is the
        // last character of the span and is therefore going away too — hence
        // `<=` and not `<`. Getting this wrong leaves one stale entry behind on
        // every multi-line deletion.
        var last = first
        while last < lineStarts.count && lineStarts[last] <= oldEnd { last += 1 }

        // A paste can be megabytes, so the edited span is scanned the same fast
        // way as a full rebuild.
        let inserted = Self.newlineOffsets(in: ns, range: editedRange)

        var tail = Array(lineStarts[last...])
        if delta != 0 {
            for i in 0..<tail.count { tail[i] += delta }
        }
        lineStarts = Array(lineStarts[..<first]) + inserted + tail
    }

    // MARK: - NSTextStorage primitives

    override var string: String { backing.string }

    override func attributes(at location: Int,
                             effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard backing.length > 0 else { return defaultAttributes }
        return backing.attributes(at: min(location, backing.length - 1), effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        version &+= 1
        edited(.editedCharacters, range: range,
               changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func processEditing() {
        if editedMask.contains(.editedCharacters) {
            updateLineIndex(editedRange: editedRange, delta: changeInLength)
            highlight(range: paragraphRange(for: editedRange))
            scheduleHighlightPass()
        }
        super.processEditing()
    }

    // MARK: - Highlighting

    var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: theme.foreground]
    }

    func rehighlightAll() {
        pendingWorkItem?.cancel()
        lastHighlightedWindow = NSRange(location: 0, length: 0)
        let full = NSRange(location: 0, length: length)
        guard full.length > 0 else { return }

        beginEditing()
        backing.setAttributes(defaultAttributes, range: full)
        edited(.editedAttributes, range: full, changeInLength: 0)
        endEditing()

        scheduleHighlightPass(immediate: true)
    }

    /// Called when the document is first shown and on every scroll: the
    /// window moved, so different text needs colouring.
    func highlightVisibleRegion() {
        guard isUsingWindowedHighlighting else { return }
        let window = highlightWindow()
        // Re-run only when the visible area has drifted outside what is coloured.
        let covered = NSIntersectionRange(window, lastHighlightedWindow)
        if covered.length >= window.length - 16 { return }
        scheduleHighlightPass(immediate: true)
    }

    /// The span of text worth colouring right now.
    private func highlightWindow() -> NSRange {
        let total = length
        guard isUsingWindowedHighlighting else { return NSRange(location: 0, length: total) }

        let visible = visibleRangeProvider?() ?? NSRange(location: 0, length: min(total, 20_000))
        let start = max(0, visible.location - contextWindow)
        let end = min(total, NSMaxRange(visible) + visiblePadding)
        let ns = backing.string as NSString

        // Snap to line boundaries so line-anchored regex rules still match.
        let snappedStart = start > 0 ? ns.paragraphRange(for: NSRange(location: start, length: 0)).location : 0
        let snappedEnd = end < total ? NSMaxRange(ns.paragraphRange(for: NSRange(location: end, length: 0))) : total
        return NSRange(location: snappedStart, length: max(0, snappedEnd - snappedStart))
    }

    private func scheduleHighlightPass(immediate: Bool = false) {
        pendingWorkItem?.cancel()
        guard syntaxHighlightingEnabled, language.flavor != .plain, length > 0, length <= hardLimit else {
            return
        }

        let window = highlightWindow()
        guard window.length > 0 else { return }

        // Only the window is copied out, so the cost of a pass is bounded by
        // what is on screen rather than by the size of the file.
        let chunk = (backing.string as NSString).substring(with: window)
        let currentVersion = version
        let localScanner = scanner
        let offset = window.location

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let tokens = localScanner.tokenize(chunk)
            DispatchQueue.main.async {
                guard self.version == currentVersion else { return }
                self.beginEditing()
                self.applyTokens(tokens, offset: offset, in: window)
                self.endEditing()
                self.lastHighlightedWindow = window
            }
        }
        pendingWorkItem = work
        // Larger documents get a longer debounce: a burst of typing should not
        // queue a scan per keystroke.
        let delay = immediate ? 0.0 : (length > wholeDocumentLimit ? 0.18 : 0.06)
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Synchronous, small-range pass used while typing.
    private func highlight(range: NSRange) {
        guard syntaxHighlightingEnabled, language.flavor != .plain else { return }
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: length))
        guard clamped.length > 0, clamped.length < 200_000 else { return }
        let chunk = (backing.string as NSString).substring(with: clamped)
        applyTokens(scanner.tokenize(chunk), offset: clamped.location, in: clamped)
    }

    private func applyTokens(_ tokens: [Token], offset: Int, in range: NSRange) {
        let bounds = NSRange(location: 0, length: length)
        let target = NSIntersectionRange(range, bounds)
        guard target.length > 0 else { return }

        backing.setAttributes(defaultAttributes, range: target)
        for token in tokens {
            let shifted = NSRange(location: token.range.location + offset, length: token.range.length)
            let r = NSIntersectionRange(shifted, target)
            guard r.length > 0 else { continue }
            var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: theme.color(for: token.type)]
            switch token.type {
            case .comment, .docComment, .emphasis:
                attrs[.font] = italic(font)
            case .strong, .heading:
                attrs[.font] = bold(font)
            case .link:
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            default:
                break
            }
            backing.addAttributes(attrs, range: r)
        }
        edited(.editedAttributes, range: target, changeInLength: 0)
    }

    private var italicCache: [CGFloat: UIFont] = [:]
    private var boldCache: [CGFloat: UIFont] = [:]

    private func italic(_ font: UIFont) -> UIFont {
        if let cached = italicCache[font.pointSize] { return cached }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) else { return font }
        let result = UIFont(descriptor: descriptor, size: font.pointSize)
        italicCache[font.pointSize] = result
        return result
    }

    private func bold(_ font: UIFont) -> UIFont {
        if let cached = boldCache[font.pointSize] { return cached }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else { return font }
        let result = UIFont(descriptor: descriptor, size: font.pointSize)
        boldCache[font.pointSize] = result
        return result
    }

    /// Expands a range to whole paragraphs plus one line either side, so short
    /// multi-line constructs recolour immediately rather than on the async pass.
    private func paragraphRange(for range: NSRange) -> NSRange {
        let ns = backing.string as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(range.location, ns.length)
        let safe = NSRange(location: location, length: min(range.length, ns.length - location))
        var result = ns.paragraphRange(for: safe)
        if result.location > 0 {
            let previous = ns.paragraphRange(for: NSRange(location: result.location - 1, length: 0))
            result = NSUnionRange(result, previous)
        }
        let end = NSMaxRange(result)
        if end < ns.length {
            let next = ns.paragraphRange(for: NSRange(location: end, length: 0))
            result = NSUnionRange(result, next)
        }
        return result
    }

    /// Called after the text view swaps in a whole new document.
    func documentDidChangeWholesale() {
        rebuildLineIndex()
        rehighlightAll()
    }
}
