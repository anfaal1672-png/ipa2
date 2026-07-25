import SwiftUI
import UIKit

/// Bridge object that lets SwiftUI drive the underlying text view (find &
/// replace, jump to line, indent commands, caret readout).
final class EditorProxy: ObservableObject {

    weak var textView: CodeTextView?
    @Published var caretLine: Int = 1
    @Published var caretColumn: Int = 1
    @Published var selectionLength: Int = 0
    @Published var matchCount: Int = 0
    @Published var currentMatch: Int = 0

    private var matches: [NSRange] = []

    func focus() { textView?.becomeFirstResponder() }
    func dismissKeyboard() { textView?.resignFirstResponder() }

    func updateCaretReadout() {
        guard let textView else { return }
        let position = textView.caretPosition
        caretLine = position.line
        caretColumn = position.column
        selectionLength = textView.selectedRange.length
    }

    // MARK: - Editing commands

    func insert(_ text: String) {
        guard let textView else { return }
        textView.insertText(text)
    }

    func indentSelection(using unit: String) {
        transformSelectedLines { unit + $0 }
    }

    func outdentSelection(using unit: String) {
        transformSelectedLines { line in
            if line.hasPrefix(unit) { return String(line.dropFirst(unit.count)) }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            var result = line
            var removed = 0
            while removed < unit.count, result.hasPrefix(" ") {
                result.removeFirst()
                removed += 1
            }
            return result
        }
    }

    func toggleComment(language: LanguageDefinition) {
        guard let prefix = language.lineComments.first else { return }
        var allCommented = true
        forEachSelectedLine { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix(prefix) { allCommented = false }
        }
        transformSelectedLines { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return line }
            if allCommented {
                guard let found = line.range(of: prefix) else { return line }
                var result = line
                result.removeSubrange(found)
                if result.hasPrefix(" ") { result.removeFirst() }
                return result
            }
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            return String(leading) + prefix + " " + String(line.dropFirst(leading.count))
        }
    }

    func duplicateLine() {
        guard let textView else { return }
        let ns = textView.text as NSString
        let range = ns.paragraphRange(for: textView.selectedRange)
        let line = ns.substring(with: range)
        let insertion = line.hasSuffix("\n") ? line : "\n" + line
        textView.selectedRange = NSRange(location: NSMaxRange(range), length: 0)
        textView.insertText(insertion)
    }

    func deleteLine() {
        guard let textView else { return }
        let ns = textView.text as NSString
        let range = ns.paragraphRange(for: textView.selectedRange)
        guard range.length > 0, let textRange = textView.textRange(from: range) else { return }
        textView.replace(textRange, withText: "")
    }

    func goToLine(_ line: Int) {
        guard let textView else { return }
        let ns = textView.text as NSString
        var index = 0
        var current = 1
        while current < line, index < ns.length {
            let found = ns.range(of: "\n", options: [], range: NSRange(location: index, length: ns.length - index))
            if found.location == NSNotFound { break }
            index = found.location + 1
            current += 1
        }
        textView.selectedRange = NSRange(location: min(index, ns.length), length: 0)
        textView.scrollRangeToVisible(textView.selectedRange)
        updateCaretReadout()
    }

    private func forEachSelectedLine(_ body: (String) -> Void) {
        guard let textView else { return }
        let ns = textView.text as NSString
        let range = ns.paragraphRange(for: textView.selectedRange)
        ns.substring(with: range).components(separatedBy: "\n").forEach(body)
    }

    private func transformSelectedLines(_ transform: (String) -> String) {
        guard let textView else { return }
        let ns = textView.text as NSString
        let paragraph = ns.paragraphRange(for: textView.selectedRange)
        guard paragraph.length >= 0, let textRange = textView.textRange(from: paragraph) else { return }
        let original = ns.substring(with: paragraph)
        let hadTrailingNewline = original.hasSuffix("\n")
        var lines = original.components(separatedBy: "\n")
        if hadTrailingNewline { lines.removeLast() }
        let transformed = lines.map(transform).joined(separator: "\n") + (hadTrailingNewline ? "\n" : "")
        textView.replace(textRange, withText: transformed)
        let newLength = (transformed as NSString).length
        textView.selectedRange = NSRange(location: paragraph.location, length: newLength)
    }

    // MARK: - Find & replace

    func find(_ query: String, options: FindOptions) {
        guard let textView, !query.isEmpty else {
            matches = []
            matchCount = 0
            currentMatch = 0
            return
        }
        matches = Self.ranges(of: query, in: textView.text, options: options)
        matchCount = matches.count
        currentMatch = matches.isEmpty ? 0 : 1
        if let first = matches.first(where: { $0.location >= textView.selectedRange.location }) ?? matches.first {
            currentMatch = (matches.firstIndex { $0 == first } ?? 0) + 1
            select(first)
        }
    }

    func findNext() { step(by: 1) }
    func findPrevious() { step(by: -1) }

    private func step(by delta: Int) {
        guard !matches.isEmpty else { return }
        var index = currentMatch - 1 + delta
        if index < 0 { index = matches.count - 1 }
        if index >= matches.count { index = 0 }
        currentMatch = index + 1
        select(matches[index])
    }

    private func select(_ range: NSRange) {
        guard let textView else { return }
        textView.selectedRange = range
        textView.scrollRangeToVisible(range)
        updateCaretReadout()
    }

    func replaceCurrent(with replacement: String, query: String, options: FindOptions) {
        guard let textView, !matches.isEmpty, currentMatch > 0 else { return }
        let range = matches[currentMatch - 1]
        guard let textRange = textView.textRange(from: range) else { return }
        textView.replace(textRange, withText: replacement)
        find(query, options: options)
    }

    func replaceAll(with replacement: String, query: String, options: FindOptions) {
        guard let textView, !query.isEmpty else { return }
        let ranges = Self.ranges(of: query, in: textView.text, options: options)
        guard !ranges.isEmpty else { return }
        let ns = NSMutableString(string: textView.text)
        for range in ranges.reversed() {
            ns.replaceCharacters(in: range, with: replacement)
        }
        let selection = textView.selectedRange
        textView.text = ns as String
        textView.selectedRange = NSRange(location: min(selection.location, ns.length), length: 0)
        textView.delegate?.textViewDidChange?(textView)
        find(query, options: options)
    }

    static func ranges(of query: String, in text: String, options: FindOptions) -> [NSRange] {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var result: [NSRange] = []

        if options.useRegex {
            var regexOptions: NSRegularExpression.Options = []
            if !options.caseSensitive { regexOptions.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: query, options: regexOptions) else { return [] }
            regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
                if let match, match.range.length > 0 { result.append(match.range) }
            }
            return result
        }

        var searchOptions: NSString.CompareOptions = [.literal]
        if !options.caseSensitive { searchOptions.insert(.caseInsensitive) }
        var location = 0
        while location < ns.length {
            let found = ns.range(of: query, options: searchOptions,
                                 range: NSRange(location: location, length: ns.length - location))
            if found.location == NSNotFound { break }
            if options.wholeWord {
                let before = found.location > 0 ? ns.character(at: found.location - 1) : 0
                let afterIndex = NSMaxRange(found)
                let after = afterIndex < ns.length ? ns.character(at: afterIndex) : 0
                if !isWordCharacter(before) && !isWordCharacter(after) { result.append(found) }
            } else {
                result.append(found)
            }
            location = NSMaxRange(found) > found.location ? NSMaxRange(found) : found.location + 1
        }
        return result
    }

    private static func isWordCharacter(_ c: unichar) -> Bool {
        guard c != 0 else { return false }
        guard let scalar = UnicodeScalar(c) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
    }
}

struct FindOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
    var useRegex = false
}

extension UITextView {
    func textRange(from range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length) else { return nil }
        return textRange(from: start, to: end)
    }
}

// MARK: - SwiftUI wrapper

struct CodeEditorView: UIViewRepresentable {

    @ObservedObject var document: CodeDocument
    @ObservedObject var settings: EditorSettings
    let theme: EditorTheme
    let proxy: EditorProxy

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, settings: settings, proxy: proxy)
    }

    func makeUIView(context: Context) -> CodeTextView {
        let storage = CodeTextStorage()
        let textView = CodeTextView(textStorage: storage)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.storage = storage
        proxy.textView = textView

        storage.language = document.language
        storage.theme = theme
        storage.font = settings.font()
        storage.syntaxHighlightingEnabled = settings.syntaxHighlighting

        textView.text = document.text
        textView.selectedRange = document.selectedRange
        applyConfiguration(to: textView, storage: storage)

        let toolbar = KeyboardToolbar(theme: theme)
        toolbar.delegate = context.coordinator
        toolbar.configure(language: document.language, theme: theme)
        context.coordinator.toolbar = toolbar
        textView.inputAccessoryView = settings.showKeyboardToolbar ? toolbar : nil

        textView.recomputeLineCount()
        DispatchQueue.main.async { proxy.updateCaretReadout() }
        return textView
    }

    func updateUIView(_ textView: CodeTextView, context: Context) {
        guard let storage = context.coordinator.storage else { return }
        context.coordinator.document = document
        proxy.textView = textView

        if context.coordinator.documentID != document.id {
            context.coordinator.documentID = document.id
            context.coordinator.isApplyingExternalChange = true
            textView.text = document.text
            textView.selectedRange = NSRange(location: min(document.selectedRange.location,
                                                           (document.text as NSString).length), length: 0)
            context.coordinator.isApplyingExternalChange = false
        } else if textView.text != document.text && !context.coordinator.isEditing {
            context.coordinator.isApplyingExternalChange = true
            let selection = textView.selectedRange
            textView.text = document.text
            textView.selectedRange = NSRange(location: min(selection.location,
                                                           (document.text as NSString).length), length: 0)
            context.coordinator.isApplyingExternalChange = false
        }

        storage.language = document.language
        storage.theme = theme
        storage.font = settings.font()
        storage.syntaxHighlightingEnabled = settings.syntaxHighlighting
        applyConfiguration(to: textView, storage: storage)

        context.coordinator.toolbar?.configure(language: document.language, theme: theme)
        textView.inputAccessoryView = settings.showKeyboardToolbar ? context.coordinator.toolbar : nil
        textView.recomputeLineCount()
    }

    private func applyConfiguration(to textView: CodeTextView, storage: CodeTextStorage) {
        textView.theme = theme
        textView.codeFont = settings.font()
        textView.showLineNumbers = settings.showLineNumbers
        textView.highlightCurrentLine = settings.highlightCurrentLine
        textView.showIndentGuides = settings.showIndentGuides
        textView.indentWidth = settings.tabWidth

        let wraps = settings.wrapLines
        textView.textContainer.widthTracksTextView = wraps
        textView.textContainer.size = CGSize(
            width: wraps ? 0 : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)
        textView.isScrollEnabled = true
        textView.showsHorizontalScrollIndicator = !wraps
        textView.setNeedsDisplay()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, KeyboardToolbarDelegate {

        var document: CodeDocument
        let settings: EditorSettings
        let proxy: EditorProxy
        weak var textView: CodeTextView?
        weak var storage: CodeTextStorage?
        var toolbar: KeyboardToolbar?
        var documentID: UUID
        var isApplyingExternalChange = false
        var isEditing = false
        private var saveWorkItem: DispatchWorkItem?

        init(document: CodeDocument, settings: EditorSettings, proxy: EditorProxy) {
            self.document = document
            self.settings = settings
            self.proxy = proxy
            self.documentID = document.id
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalChange else { return }
            document.text = textView.text
            document.isDirty = true
            (textView as? CodeTextView)?.recomputeLineCount()
            proxy.updateCaretReadout()
            scheduleAutoSave()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            document.selectedRange = textView.selectedRange
            proxy.updateCaretReadout()
            textView.setNeedsDisplay()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            textView.setNeedsDisplay()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            textView.setNeedsDisplay()
            if settings.autoSave { try? document.save() }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            scrollView.setNeedsDisplay()
        }

        /// Auto-indent, bracket completion and smart deletion live here.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            let language = document.language
            let ns = textView.text as NSString

            // Return: copy the current line's indentation, add one level after an opener.
            if text == "\n", settings.autoIndent {
                let lineRange = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
                let line = ns.substring(with: NSRange(location: lineRange.location,
                                                      length: max(0, range.location - lineRange.location)))
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let unit = language.indentUnit ?? settings.indentString

                var insertion = "\n" + indent
                let opensBlock = language.indentAfter.contains { trimmed.hasSuffix($0) }
                if opensBlock { insertion += unit }

                // Typing return between a matching pair puts the closer on its own line.
                let nextCharacter = range.location < ns.length ? ns.substring(with: NSRange(location: range.location, length: 1)) : ""
                if opensBlock, let opener = trimmed.last.map(String.init),
                   let closer = language.autoClosePairs[opener], closer == nextCharacter {
                    let closing = "\n" + indent
                    textView.replace(textView.textRange(from: range) ?? textView.selectedTextRange!,
                                     withText: insertion + closing)
                    let newLocation = range.location + (insertion as NSString).length
                    textView.selectedRange = NSRange(location: newLocation, length: 0)
                    return false
                }

                textView.insertText(insertion)
                return false
            }

            // Auto-close pairs.
            if settings.autoCloseBrackets, text.count == 1, let closer = language.autoClosePairs[text] {
                let nextCharacter = range.location < ns.length
                    ? ns.substring(with: NSRange(location: range.location, length: 1)) : ""
                let isQuote = text == closer

                if isQuote && nextCharacter == closer {
                    textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                    return false
                }
                if range.length > 0 {
                    // wrap the selection
                    let selected = ns.substring(with: range)
                    textView.insertText(text + selected + closer)
                    textView.selectedRange = NSRange(location: range.location + 1,
                                                     length: (selected as NSString).length)
                    return false
                }
                let wordCharacterFollows = !nextCharacter.isEmpty
                    && (nextCharacter.rangeOfCharacter(from: .alphanumerics) != nil)
                if !wordCharacterFollows {
                    textView.insertText(text + closer)
                    textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                    return false
                }
            }

            // Typing a closer directly before the auto-inserted one just moves past it.
            if settings.autoCloseBrackets, text.count == 1,
               language.autoClosePairs.values.contains(text),
               range.length == 0, range.location < ns.length,
               ns.substring(with: NSRange(location: range.location, length: 1)) == text {
                textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                return false
            }

            // Backspace inside an empty pair removes both sides; inside indentation
            // removes a whole indent level.
            if text.isEmpty, range.length == 1, range.location < ns.length {
                let previous = ns.substring(with: NSRange(location: range.location, length: 1))
                let next = range.location + 1 < ns.length
                    ? ns.substring(with: NSRange(location: range.location + 1, length: 1)) : ""
                if let closer = language.autoClosePairs[previous], closer == next {
                    textView.replace(textView.textRange(from: NSRange(location: range.location, length: 2))
                                     ?? textView.selectedTextRange!, withText: "")
                    return false
                }
            }
            if text.isEmpty, range.length == 1, settings.useSpaces {
                let lineRange = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
                let prefix = ns.substring(with: NSRange(location: lineRange.location,
                                                        length: max(0, NSMaxRange(range) - lineRange.location)))
                if !prefix.isEmpty, prefix.allSatisfy({ $0 == " " }) {
                    let width = max(1, settings.tabWidth)
                    let removal = ((prefix.count - 1) % width) + 1
                    let deleteRange = NSRange(location: NSMaxRange(range) - removal, length: removal)
                    if deleteRange.location >= lineRange.location, removal > 1,
                       let textRange = textView.textRange(from: deleteRange) {
                        textView.replace(textRange, withText: "")
                        return false
                    }
                }
            }

            return true
        }

        private func scheduleAutoSave() {
            guard settings.autoSave, document.url != nil else { return }
            saveWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                try? self.document.save()
            }
            saveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        }

        // MARK: KeyboardToolbarDelegate

        func toolbarDidInsert(_ text: String) {
            textView?.insertText(text)
        }

        func toolbarDidTapTab() {
            guard let textView else { return }
            if textView.selectedRange.length > 0 {
                proxy.indentSelection(using: document.language.indentUnit ?? settings.indentString)
            } else {
                textView.insertText(document.language.indentUnit ?? settings.indentString)
            }
        }

        func toolbarDidTapOutdent() {
            proxy.outdentSelection(using: document.language.indentUnit ?? settings.indentString)
        }

        func toolbarDidTapUndo() {
            textView?.undoManager?.undo()
            if let textView { textViewDidChange(textView) }
        }

        func toolbarDidTapRedo() {
            textView?.undoManager?.redo()
            if let textView { textViewDidChange(textView) }
        }

        func toolbarDidMoveCaret(by offset: Int) {
            guard let textView else { return }
            let length = (textView.text as NSString).length
            let location = max(0, min(length, textView.selectedRange.location + offset))
            textView.selectedRange = NSRange(location: location, length: 0)
        }

        func toolbarDidTapDismiss() {
            textView?.resignFirstResponder()
        }
    }
}
