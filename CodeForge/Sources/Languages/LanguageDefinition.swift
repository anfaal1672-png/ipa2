import Foundation

/// The kind of token produced by the scanner. Themes map each case to a colour.
enum TokenType: UInt8, Hashable {
    case plain
    case keyword
    case controlKeyword
    case type
    case constant
    case builtin
    case function
    case property
    case variable
    case number
    case string
    case escape
    case interpolation
    case regex
    case comment
    case docComment
    case `operator`
    case punctuation
    case preprocessor
    case annotation
    case tag
    case attribute
    case heading
    case link
    case emphasis
    case strong
    case inserted
    case deleted
    case invalid
}

struct Token {
    var type: TokenType
    var range: NSRange
}

/// Scanning strategy. Most programming languages share the C-like shape
/// (identifiers, numbers, quoted strings, line/block comments); markup and
/// configuration formats need dedicated scanners.
enum LanguageFlavor {
    case cLike
    case markup      // HTML, XML, SVG, Vue, Svelte …
    case css
    case markdown
    case ini
    case diff
    case plain
}

struct StringRule {
    var open: String
    var close: String
    var escape: Character?
    var multiline: Bool
    var interpolationOpen: String?
    var interpolationClose: String?
    var raw: Bool

    init(open: String,
         close: String? = nil,
         escape: Character? = "\\",
         multiline: Bool = false,
         interpolationOpen: String? = nil,
         interpolationClose: String? = nil,
         raw: Bool = false) {
        self.open = open
        self.close = close ?? open
        self.escape = escape
        self.multiline = multiline
        self.interpolationOpen = interpolationOpen
        self.interpolationClose = interpolationClose
        self.raw = raw
    }
}

struct BlockComment {
    var open: String
    var close: String
    var doc: Bool
    var nested: Bool

    init(_ open: String, _ close: String, doc: Bool = false, nested: Bool = false) {
        self.open = open
        self.close = close
        self.doc = doc
        self.nested = nested
    }
}

/// A regex rule applied before the generic scanner. Used for constructs the
/// generic scanner cannot express (attributes, preprocessor lines, sigils …).
struct RegexRule {
    var pattern: String
    var type: TokenType
    var group: Int
    var options: NSRegularExpression.Options

    init(_ pattern: String, _ type: TokenType, group: Int = 0,
         options: NSRegularExpression.Options = []) {
        self.pattern = pattern
        self.type = type
        self.group = group
        self.options = options
    }
}

struct LanguageDefinition {
    var id: String
    var name: String
    var extensions: [String] = []
    var filenames: [String] = []
    var shebangs: [String] = []
    var flavor: LanguageFlavor = .cLike

    var lineComments: [String] = []
    var docLineComments: [String] = []
    var blockComments: [BlockComment] = []
    var strings: [StringRule] = []

    var keywords: Set<String> = []
    var controlKeywords: Set<String> = []
    var types: Set<String> = []
    var constants: Set<String> = []
    var builtins: Set<String> = []

    var caseInsensitive: Bool = false
    /// Characters (besides letters/digits/underscore) that may start or continue
    /// an identifier — `$` in JS/PHP, `-` in Lisp/CSS, `@` in Ruby …
    var identifierExtras: Set<Character> = ["_"]
    var identifierStartExtras: Set<Character> = ["_"]
    var operatorCharacters: Set<Character> = Set("+-*/%=<>!&|^~?:.")
    var punctuation: Set<Character> = Set("()[]{},;")

    /// Highlight `name(` as a function call.
    var highlightCalls: Bool = true
    /// Highlight `.name` as a property access.
    var highlightProperties: Bool = true
    var numbersAllowUnderscore: Bool = true
    var rules: [RegexRule] = []

    // Editing behaviour
    var indentUnit: String? = nil          // nil = use global setting
    var autoClosePairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
    var indentAfter: [String] = ["{", "(", "[", ":"]
    var dedentTokens: [String] = ["}", ")", "]", "end", "endif", "fi", "esac", "done"]
    var keyboardExtras: [String] = []

    func isKeyword(_ word: String) -> Bool {
        contains(keywords, word)
    }

    func lookup(_ word: String) -> TokenType? {
        if contains(controlKeywords, word) { return .controlKeyword }
        if contains(keywords, word) { return .keyword }
        if contains(types, word) { return .type }
        if contains(constants, word) { return .constant }
        if contains(builtins, word) { return .builtin }
        return nil
    }

    private func contains(_ set: Set<String>, _ word: String) -> Bool {
        if set.contains(word) { return true }
        if caseInsensitive { return set.contains(word.lowercased()) }
        return false
    }
}

extension LanguageDefinition {
    /// Convenience builder for the very common "C-like" shape.
    static func cLike(id: String,
                      name: String,
                      extensions: [String],
                      filenames: [String] = [],
                      keywords: String,
                      controlKeywords: String = "if else for while do switch case default break continue return goto try catch finally throw",
                      types: String = "",
                      constants: String = "true false null",
                      builtins: String = "",
                      lineComments: [String] = ["//"],
                      blockComments: [BlockComment] = [BlockComment("/*", "*/")],
                      strings: [StringRule] = [StringRule(open: "\""), StringRule(open: "'")],
                      rules: [RegexRule] = [],
                      identifierExtras: Set<Character> = ["_"],
                      caseInsensitive: Bool = false) -> LanguageDefinition {
        var d = LanguageDefinition(id: id, name: name, extensions: extensions, filenames: filenames)
        d.lineComments = lineComments
        d.blockComments = blockComments
        d.strings = strings
        d.keywords = Set(keywords.split(separator: " ").map(String.init))
        d.controlKeywords = Set(controlKeywords.split(separator: " ").map(String.init))
        d.types = Set(types.split(separator: " ").map(String.init))
        d.constants = Set(constants.split(separator: " ").map(String.init))
        d.builtins = Set(builtins.split(separator: " ").map(String.init))
        d.rules = rules
        d.identifierExtras = identifierExtras.union(["_"])
        d.identifierStartExtras = identifierExtras.union(["_"])
        d.caseInsensitive = caseInsensitive
        return d
    }
}
