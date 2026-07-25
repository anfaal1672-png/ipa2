import UIKit

/// `NSTextStorage` subclass that keeps syntax colouring in sync with edits.
///
/// Two passes run for every change:
///  * a synchronous pass over the edited paragraphs so typing feels instant;
///  * a debounced asynchronous pass over the whole document on a background
///    queue, which fixes up constructs that span many lines (block comments,
///    heredocs, template literals …).
final class CodeTextStorage: NSTextStorage {

    private let backing = NSMutableAttributedString()
    private let queue = DispatchQueue(label: "codeforge.highlighter", qos: .userInitiated)

    private var version: Int = 0
    private var pendingWorkItem: DispatchWorkItem?

    /// Documents larger than this are highlighted around the edit only; a full
    /// pass on multi-megabyte files would waste battery for no visible gain.
    private let fullPassLimit = 1_500_000

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
        didSet { rehighlightAll() }
    }

    var syntaxHighlightingEnabled: Bool = true {
        didSet { rehighlightAll() }
    }

    private var scanner = SyntaxScanner(language: LanguageRegistry.plainText)

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
            highlight(range: paragraphRange(for: editedRange), synchronous: true)
            scheduleFullPass()
        }
        super.processEditing()
    }

    // MARK: - Highlighting

    var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: theme.foreground]
    }

    func rehighlightAll() {
        pendingWorkItem?.cancel()
        let full = NSRange(location: 0, length: length)
        guard full.length > 0 else { return }
        beginEditing()
        applyTokens(scannedTokens(in: full), in: full)
        endEditing()
        scheduleFullPass()
    }

    private func scheduleFullPass() {
        guard syntaxHighlightingEnabled, language.flavor != .plain else { return }
        pendingWorkItem?.cancel()
        let snapshot = backing.string
        let currentVersion = version
        let limit = fullPassLimit
        let localScanner = scanner

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard (snapshot as NSString).length <= limit else { return }
            let tokens = localScanner.tokenize(snapshot)
            DispatchQueue.main.async {
                guard self.version == currentVersion else { return }
                let full = NSRange(location: 0, length: self.length)
                self.beginEditing()
                self.applyTokens(tokens, in: full)
                self.endEditing()
            }
        }
        pendingWorkItem = work
        queue.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func highlight(range: NSRange, synchronous: Bool) {
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: length))
        guard clamped.length > 0 else { return }
        applyTokens(scannedTokens(in: clamped), in: clamped)
    }

    private func scannedTokens(in range: NSRange) -> [Token] {
        guard syntaxHighlightingEnabled, language.flavor != .plain else { return [] }
        return scanner.tokenize(backing.string, range: range)
    }

    private func applyTokens(_ tokens: [Token], in range: NSRange) {
        let bounds = NSRange(location: 0, length: length)
        let target = NSIntersectionRange(range, bounds)
        guard target.length > 0 else { return }

        backing.setAttributes(defaultAttributes, range: target)
        for token in tokens {
            let r = NSIntersectionRange(token.range, bounds)
            guard r.length > 0 else { continue }
            var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: theme.color(for: token.type)]
            switch token.type {
            case .comment, .docComment:
                attrs[.font] = italic(font)
            case .strong, .heading:
                attrs[.font] = bold(font)
            case .emphasis:
                attrs[.font] = italic(font)
            case .link:
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            default:
                break
            }
            backing.addAttributes(attrs, range: r)
        }
        edited(.editedAttributes, range: target, changeInLength: 0)
    }

    private func italic(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private func bold(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    /// Expands a range to whole paragraphs and grows it a little so short
    /// multi-line constructs recolour immediately rather than on the async pass.
    private func paragraphRange(for range: NSRange) -> NSRange {
        let ns = backing.string as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        let safe = NSRange(location: min(range.location, ns.length),
                           length: min(range.length, ns.length - min(range.location, ns.length)))
        var result = ns.paragraphRange(for: safe)
        // include the previous and next line
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
}
