import Foundation

/// One open buffer. Text lives in memory; `save()` writes it back to disk.
final class CodeDocument: ObservableObject, Identifiable {

    let id = UUID()
    @Published var url: URL?
    @Published var isDirty: Bool = false
    @Published var languageOverride: LanguageDefinition?

    /// The buffer's text.
    ///
    /// While a document is open the text view owns the live text; this copy is
    /// refreshed on a debounce (and always before saving), because copying a
    /// multi-megabyte string on every keystroke is by itself enough to make
    /// typing stutter.
    private(set) var text: String

    /// Bumped only when the text is replaced from *outside* the editor (load,
    /// replace-all, revert). The editor compares revisions instead of
    /// comparing whole strings, which would be O(n) on every SwiftUI update.
    private(set) var revision: Int = 0

    private var cachedLineCount: Int = 1

    /// Bumped whenever `text` changes, from any source. Lets a background save
    /// tell whether the buffer moved on while it was writing, without comparing
    /// (or measuring) the whole string.
    private var editEpoch: Int = 0

    /// False for a tab restored from the last session whose bytes have not been
    /// read yet. Reading every previously open file at launch is the difference
    /// between a fast start and one that stalls on a few megabytes.
    private(set) var isLoaded: Bool = true
    /// Caret position restored when the tab is re-selected.
    var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var encoding: String.Encoding = .utf8
    var lineEnding: LineEnding = .lf

    enum LineEnding: String, CaseIterable, Identifiable {
        case lf = "LF"
        case crlf = "CRLF"
        case cr = "CR"
        var id: String { rawValue }
        var characters: String {
            switch self {
            case .lf: return "\n"
            case .crlf: return "\r\n"
            case .cr: return "\r"
            }
        }
    }

    init(url: URL?, text: String = "") {
        self.url = url
        self.text = text
        self.cachedLineCount = CodeDocument.countLines(in: text)
    }

    /// A tab whose contents are read the first time it is looked at.
    static func placeholder(url: URL) -> CodeDocument {
        let document = CodeDocument(url: url, text: "")
        document.isLoaded = false
        return document
    }

    /// Reads the file if this is still a placeholder. Cheap and idempotent
    /// otherwise, so callers can be liberal about it.
    /// Set when a restored tab could not be read. Saving stays blocked in that
    /// case: an empty buffer standing in for a file that exists must never be
    /// written back over it.
    private(set) var loadFailed = false

    func ensureLoaded() {
        guard !isLoaded, let url else { return }
        isLoaded = true
        guard let loaded = try? CodeDocument.load(from: url) else {
            loadFailed = true
            return
        }
        encoding = loaded.encoding
        lineEnding = loaded.lineEnding
        text = loaded.text
        editEpoch &+= 1
        cachedLineCount = CodeDocument.countLines(in: loaded.text)
        revision &+= 1
        isDirty = false
        objectWillChange.send()
    }

    /// Text arriving from the editor: no revision bump, so the editor is not
    /// asked to reload what it just typed.
    func syncFromEditor(text: String, lineCount: Int) {
        self.text = text
        editEpoch &+= 1
        self.cachedLineCount = max(1, lineCount)
    }

    /// Text arriving from anywhere else; the editor reloads on the next update.
    func replaceText(_ newText: String) {
        text = newText
        editEpoch &+= 1
        cachedLineCount = CodeDocument.countLines(in: newText)
        revision &+= 1
        isDirty = true
        objectWillChange.send()
    }

    private static func countLines(in text: String) -> Int {
        guard !text.isEmpty else { return 1 }
        var count = 1
        for character in text where character == "\n" { count += 1 }
        return count
    }

    var name: String { url?.lastPathComponent ?? "Untitled" }

    var language: LanguageDefinition {
        if let languageOverride { return languageOverride }
        if let url { return LanguageRegistry.shared.language(forFilename: url.lastPathComponent) }
        return LanguageRegistry.shared.language(forContent: text) ?? LanguageRegistry.plainText
    }

    /// Cached: the status bar reads this on every SwiftUI update, and counting
    /// newlines through a megabyte of text at that rate is not free.
    var lineCount: Int { cachedLineCount }

    // MARK: - Disk I/O

    static func load(from url: URL) throws -> CodeDocument {
        let data = try Data(contentsOf: url)
        var usedEncoding: String.Encoding = .utf8
        var contents = String(data: data, encoding: .utf8)
        if contents == nil {
            var raw: NSString?
            let detected = NSString.stringEncoding(for: data, encodingOptions: nil,
                                                   convertedString: &raw, usedLossyConversion: nil)
            if detected != 0, let raw {
                usedEncoding = String.Encoding(rawValue: detected)
                contents = raw as String
            }
        }
        guard let contents else {
            throw NSError(domain: "CodeForge", code: 1, userInfo: [
                NSLocalizedDescriptionKey: L("This file is not text (binary content).")
            ])
        }
        let document = CodeDocument(url: url, text: contents)
        document.encoding = usedEncoding
        document.lineEnding = contents.contains("\r\n") ? .crlf : (contents.contains("\r") ? .cr : .lf)
        return document
    }

    func save() throws {
        guard let url else { return }
        // A placeholder holds an empty string, and writing that would erase the
        // file it stands for.
        guard isLoaded, !loadFailed else { return }
        var output = text
        if lineEnding != .lf {
            output = text.replacingOccurrences(of: "\n", with: lineEnding.characters)
        }
        guard let data = output.data(using: encoding) ?? output.data(using: .utf8) else { return }
        try data.write(to: url, options: .atomic)
        isDirty = false
    }

    private static let writeQueue = DispatchQueue(label: "codeforge.save", qos: .utility)

    /// Autosave path: encodes and writes off the main thread.
    ///
    /// Encoding a multi-megabyte buffer and writing it out takes long enough to
    /// drop frames, and autosave fires while the user is still working. The text
    /// is snapshotted first, so a later edit cannot change what is being
    /// written. Explicit saves still use `save()`, where errors reach the user.
    func autosave() {
        guard let url, isLoaded, !loadFailed else { return }
        let snapshot = text
        let ending = lineEnding
        let encoding = self.encoding
        let epoch = editEpoch
        Self.writeQueue.async { [weak self] in
            let output = ending == .lf
                ? snapshot
                : snapshot.replacingOccurrences(of: "\n", with: ending.characters)
            guard let data = output.data(using: encoding) ?? output.data(using: .utf8),
                  (try? data.write(to: url, options: .atomic)) != nil else { return }
            DispatchQueue.main.async {
                guard let self, self.editEpoch == epoch else { return }
                self.isDirty = false
            }
        }
    }

    func save(to url: URL) throws {
        self.url = url
        try save()
    }
}
