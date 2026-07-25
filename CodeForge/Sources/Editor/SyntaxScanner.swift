import Foundation

/// A hand written, allocation-light lexer that works directly on UTF-16 code
/// units so the token ranges can be handed straight to `NSTextStorage`.
///
/// The scanner is deliberately generic: a `LanguageDefinition` describes the
/// comment/string/keyword shape of a language and the scanner turns any text
/// into tokens. Markup, CSS, Markdown, INI and diff get dedicated passes
/// because their structure cannot be expressed with the generic rules.
struct SyntaxScanner {

    let language: LanguageDefinition

    init(language: LanguageDefinition) {
        self.language = language
    }

    // MARK: - Entry point

    func tokenize(_ text: String, range: NSRange? = nil) -> [Token] {
        let units = Array(text.utf16)
        let full = NSRange(location: 0, length: units.count)
        let region = range.map { NSIntersectionRange($0, full) } ?? full
        guard region.length > 0 else { return [] }

        var tokens: [Token] = []
        tokens.reserveCapacity(region.length / 6 + 16)
        scan(units, from: region.location, to: NSMaxRange(region),
             language: language, into: &tokens)
        applyRegexRules(text: text, units: units, region: region, language: language, tokens: &tokens)
        tokens.sort { $0.range.location < $1.range.location }
        return tokens
    }

    // MARK: - Dispatch

    private func scan(_ u: [unichar], from start: Int, to end: Int,
                      language lang: LanguageDefinition, into tokens: inout [Token]) {
        switch lang.flavor {
        case .cLike:    scanCLike(u, start, end, lang, &tokens)
        case .markup:   scanMarkup(u, start, end, lang, &tokens)
        case .css:      scanCSS(u, start, end, lang, &tokens)
        case .markdown: scanMarkdown(u, start, end, lang, &tokens)
        case .ini:      scanINI(u, start, end, lang, &tokens)
        case .diff:     scanDiff(u, start, end, &tokens)
        case .plain:    break
        }
    }

    // MARK: - Generic C-like scanner

    private func scanCLike(_ u: [unichar], _ start: Int, _ end: Int,
                           _ lang: LanguageDefinition, _ tokens: inout [Token]) {
        var i = start
        var lastMeaningful: unichar = 0
        var lastWasValue = false   // used to disambiguate regex literals from division

        while i < end {
            let c = u[i]

            if isSpace(c) { i += 1; continue }

            // ---- comments -------------------------------------------------
            if let (len, doc) = matchLineComment(u, i, end, lang) {
                var j = i + len
                while j < end && u[j] != 0x0A { j += 1 }
                tokens.append(Token(type: doc ? .docComment : .comment,
                                    range: NSRange(location: i, length: j - i)))
                i = j
                lastWasValue = false
                continue
            }
            if let block = matchBlockComment(u, i, end, lang) {
                let j = consumeBlockComment(u, i, end, block)
                tokens.append(Token(type: block.doc ? .docComment : .comment,
                                    range: NSRange(location: i, length: j - i)))
                i = j
                lastWasValue = false
                continue
            }

            // ---- strings --------------------------------------------------
            if let rule = matchString(u, i, end, lang) {
                i = consumeString(u, i, end, rule, &tokens)
                lastWasValue = true
                continue
            }

            // ---- numbers --------------------------------------------------
            if isDigit(c) || (c == UInt16(ascii: ".") && i + 1 < end && isDigit(u[i + 1]) && !lastWasValue) {
                let j = consumeNumber(u, i, end, lang)
                tokens.append(Token(type: .number, range: NSRange(location: i, length: j - i)))
                i = j
                lastWasValue = true
                continue
            }

            // ---- identifiers ----------------------------------------------
            if isIdentifierStart(c, lang) {
                var j = i + 1
                while j < end && isIdentifierPart(u[j], lang) { j += 1 }
                let word = String(utf16CodeUnits: Array(u[i..<j]), count: j - i)
                let range = NSRange(location: i, length: j - i)

                if let type = lang.lookup(word) {
                    tokens.append(Token(type: type, range: range))
                    lastWasValue = (type == .constant || type == .type)
                } else if lang.highlightProperties && lastMeaningful == UInt16(ascii: ".") {
                    tokens.append(Token(type: nextNonSpace(u, j, end) == UInt16(ascii: "(") && lang.highlightCalls
                                        ? .function : .property, range: range))
                    lastWasValue = true
                } else if lang.highlightCalls && nextNonSpace(u, j, end) == UInt16(ascii: "(") {
                    tokens.append(Token(type: .function, range: range))
                    lastWasValue = false
                } else if isTypeShaped(word) {
                    tokens.append(Token(type: .type, range: range))
                    lastWasValue = true
                } else {
                    lastWasValue = true
                }
                lastMeaningful = u[j - 1]
                i = j
                continue
            }

            // ---- regex literals (JS-family) -------------------------------
            if c == UInt16(ascii: "/") && lang.rules.isEmpty == false && supportsRegexLiteral(lang) && !lastWasValue {
                if let j = consumeRegexLiteral(u, i, end) {
                    tokens.append(Token(type: .regex, range: NSRange(location: i, length: j - i)))
                    i = j
                    lastWasValue = true
                    continue
                }
            }

            // ---- operators & punctuation ----------------------------------
            if lang.punctuation.contains(Character(UnicodeScalar(c) ?? " ")) {
                tokens.append(Token(type: .punctuation, range: NSRange(location: i, length: 1)))
                lastMeaningful = c
                lastWasValue = (c == UInt16(ascii: ")") || c == UInt16(ascii: "]"))
                i += 1
                continue
            }
            if let scalar = UnicodeScalar(c), lang.operatorCharacters.contains(Character(scalar)) {
                var j = i + 1
                while j < end, let s = UnicodeScalar(u[j]), lang.operatorCharacters.contains(Character(s)) {
                    // don't swallow the start of a comment
                    if matchLineComment(u, j, end, lang) != nil || matchBlockComment(u, j, end, lang) != nil { break }
                    j += 1
                }
                tokens.append(Token(type: .operator, range: NSRange(location: i, length: j - i)))
                lastMeaningful = u[j - 1]
                lastWasValue = false
                i = j
                continue
            }

            lastMeaningful = c
            lastWasValue = false
            i += 1
        }
    }

    private func supportsRegexLiteral(_ lang: LanguageDefinition) -> Bool {
        ["javascript", "typescript", "jsx", "tsx", "ruby", "perl", "groovy"].contains(lang.id)
    }

    private func consumeRegexLiteral(_ u: [unichar], _ start: Int, _ end: Int) -> Int? {
        var i = start + 1
        var inClass = false
        while i < end {
            let c = u[i]
            if c == 0x0A { return nil }
            if c == UInt16(ascii: "\\") { i += 2; continue }
            if c == UInt16(ascii: "[") { inClass = true }
            else if c == UInt16(ascii: "]") { inClass = false }
            else if c == UInt16(ascii: "/") && !inClass {
                i += 1
                while i < end && isLetter(u[i]) { i += 1 }
                return i
            }
            i += 1
        }
        return nil
    }

    // MARK: - Comment / string matching helpers

    private func matchLineComment(_ u: [unichar], _ i: Int, _ end: Int,
                                  _ lang: LanguageDefinition) -> (Int, Bool)? {
        for prefix in lang.docLineComments where matches(u, i, end, prefix) {
            return (prefix.utf16.count, true)
        }
        for prefix in lang.lineComments where matches(u, i, end, prefix) {
            return (prefix.utf16.count, false)
        }
        return nil
    }

    private func matchBlockComment(_ u: [unichar], _ i: Int, _ end: Int,
                                   _ lang: LanguageDefinition) -> BlockComment? {
        var best: BlockComment?
        for block in lang.blockComments where matches(u, i, end, block.open) {
            if best == nil || block.open.utf16.count > best!.open.utf16.count { best = block }
        }
        return best
    }

    private func consumeBlockComment(_ u: [unichar], _ start: Int, _ end: Int,
                                     _ block: BlockComment) -> Int {
        var i = start + block.open.utf16.count
        var depth = 1
        while i < end {
            if block.nested && matches(u, i, end, block.open) {
                depth += 1
                i += block.open.utf16.count
                continue
            }
            if matches(u, i, end, block.close) {
                depth -= 1
                i += block.close.utf16.count
                if depth == 0 { return i }
                continue
            }
            i += 1
        }
        return end
    }

    private func matchString(_ u: [unichar], _ i: Int, _ end: Int,
                             _ lang: LanguageDefinition) -> StringRule? {
        var best: StringRule?
        for rule in lang.strings where matches(u, i, end, rule.open) {
            if best == nil || rule.open.utf16.count > best!.open.utf16.count { best = rule }
        }
        return best
    }

    /// Consumes a string literal, emitting escape and interpolation tokens
    /// nested inside the string token so they can be coloured separately.
    private func consumeString(_ u: [unichar], _ start: Int, _ end: Int,
                               _ rule: StringRule, _ tokens: inout [Token]) -> Int {
        var i = start + rule.open.utf16.count
        var inner: [Token] = []
        while i < end {
            let c = u[i]
            if c == 0x0A && !rule.multiline {
                break
            }
            if let esc = rule.escape, !rule.raw, c == UInt16(esc.unicodeScalars.first!.value) {
                let len = min(2, end - i)
                inner.append(Token(type: .escape, range: NSRange(location: i, length: len)))
                i += len
                continue
            }
            if let open = rule.interpolationOpen, let close = rule.interpolationClose,
               matches(u, i, end, open) {
                var j = i + open.utf16.count
                var depth = 1
                while j < end {
                    if matches(u, j, end, open) { depth += 1; j += open.utf16.count; continue }
                    if matches(u, j, end, close) {
                        depth -= 1
                        j += close.utf16.count
                        if depth == 0 { break }
                        continue
                    }
                    j += 1
                }
                inner.append(Token(type: .interpolation, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if matches(u, i, end, rule.close) {
                i += rule.close.utf16.count
                tokens.append(Token(type: .string, range: NSRange(location: start, length: i - start)))
                tokens.append(contentsOf: inner)
                return i
            }
            i += 1
        }
        tokens.append(Token(type: .string, range: NSRange(location: start, length: i - start)))
        tokens.append(contentsOf: inner)
        return i
    }

    private func consumeNumber(_ u: [unichar], _ start: Int, _ end: Int,
                               _ lang: LanguageDefinition) -> Int {
        var i = start
        if u[i] == UInt16(ascii: "0"), i + 1 < end {
            let n = u[i + 1] | 0x20
            if n == UInt16(ascii: "x") || n == UInt16(ascii: "b") || n == UInt16(ascii: "o") {
                i += 2
                while i < end && (isHexDigit(u[i]) || (lang.numbersAllowUnderscore && u[i] == UInt16(ascii: "_"))) { i += 1 }
                while i < end && isLetter(u[i]) { i += 1 }   // suffixes: u, L, ul …
                return i
            }
        }
        var seenDot = false
        var seenExp = false
        while i < end {
            let c = u[i]
            if isDigit(c) { i += 1; continue }
            if lang.numbersAllowUnderscore && c == UInt16(ascii: "_") { i += 1; continue }
            if c == UInt16(ascii: ".") && !seenDot && !seenExp
                && i + 1 < end && isDigit(u[i + 1]) { seenDot = true; i += 1; continue }
            if (c | 0x20) == UInt16(ascii: "e") && !seenExp && i + 1 < end
                && (isDigit(u[i + 1]) || ((u[i + 1] == UInt16(ascii: "+") || u[i + 1] == UInt16(ascii: "-"))
                                          && i + 2 < end && isDigit(u[i + 2]))) {
                seenExp = true
                i += 2
                continue
            }
            break
        }
        // numeric suffix (f, L, ull, px …)
        while i < end && (isLetter(u[i]) || u[i] == UInt16(ascii: "%")) { i += 1 }
        return i
    }

    // MARK: - Markup (HTML / XML)

    private func scanMarkup(_ u: [unichar], _ start: Int, _ end: Int,
                            _ lang: LanguageDefinition, _ tokens: inout [Token]) {
        var i = start
        while i < end {
            if matches(u, i, end, "<!--") {
                var j = i + 4
                while j < end && !matches(u, j, end, "-->") { j += 1 }
                j = min(end, j + 3)
                tokens.append(Token(type: .comment, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if u[i] == UInt16(ascii: "<") {
                let isClose = i + 1 < end && u[i + 1] == UInt16(ascii: "/")
                let isDecl = i + 1 < end && (u[i + 1] == UInt16(ascii: "!") || u[i + 1] == UInt16(ascii: "?"))
                var j = i + 1
                if isClose || isDecl { j += 1 }
                let nameStart = j
                while j < end && (isLetter(u[j]) || isDigit(u[j]) || u[j] == UInt16(ascii: "-")
                                  || u[j] == UInt16(ascii: ":") || u[j] == UInt16(ascii: "_")) { j += 1 }
                let name = String(utf16CodeUnits: Array(u[nameStart..<max(nameStart, j)]),
                                  count: max(0, j - nameStart)).lowercased()
                tokens.append(Token(type: .punctuation, range: NSRange(location: i, length: nameStart - i)))
                if j > nameStart {
                    tokens.append(Token(type: .tag, range: NSRange(location: nameStart, length: j - nameStart)))
                }
                // attributes
                while j < end && u[j] != UInt16(ascii: ">") {
                    if isSpace(u[j]) { j += 1; continue }
                    if u[j] == UInt16(ascii: "\"") || u[j] == UInt16(ascii: "'") {
                        let quote = u[j]
                        var k = j + 1
                        while k < end && u[k] != quote { k += 1 }
                        k = min(end, k + 1)
                        tokens.append(Token(type: .string, range: NSRange(location: j, length: k - j)))
                        j = k
                        continue
                    }
                    if isLetter(u[j]) || u[j] == UInt16(ascii: "_") || u[j] == UInt16(ascii: ":")
                        || u[j] == UInt16(ascii: "@") || u[j] == UInt16(ascii: "#") || u[j] == UInt16(ascii: "[") {
                        var k = j + 1
                        while k < end && !isSpace(u[k]) && u[k] != UInt16(ascii: "=")
                            && u[k] != UInt16(ascii: ">") && u[k] != UInt16(ascii: "\"") { k += 1 }
                        tokens.append(Token(type: .attribute, range: NSRange(location: j, length: k - j)))
                        j = k
                        continue
                    }
                    j += 1
                }
                if j < end {
                    tokens.append(Token(type: .punctuation, range: NSRange(location: j, length: 1)))
                    j += 1
                }
                i = j

                // embedded <script> / <style> bodies
                if !isClose && !isDecl && (name == "script" || name == "style") {
                    let closeTag = "</" + name
                    var k = i
                    while k < end && !matches(u, k, end, closeTag) { k += 1 }
                    if k > i {
                        let embedded = name == "script"
                            ? LanguageRegistry.shared.language(id: "javascript")
                            : LanguageRegistry.shared.language(id: "css")
                        if let embedded {
                            scan(u, from: i, to: k, language: embedded, into: &tokens)
                        }
                    }
                    i = k
                }
                continue
            }
            if u[i] == UInt16(ascii: "&") {
                var j = i + 1
                while j < end && j - i < 12 && u[j] != UInt16(ascii: ";") && !isSpace(u[j]) { j += 1 }
                if j < end && u[j] == UInt16(ascii: ";") {
                    tokens.append(Token(type: .escape, range: NSRange(location: i, length: j - i + 1)))
                    i = j + 1
                    continue
                }
            }
            i += 1
        }
    }

    // MARK: - CSS

    private func scanCSS(_ u: [unichar], _ start: Int, _ end: Int,
                         _ lang: LanguageDefinition, _ tokens: inout [Token]) {
        var i = start
        var inBlock = false
        var afterColon = false
        while i < end {
            let c = u[i]
            if isSpace(c) { i += 1; continue }
            if matches(u, i, end, "/*") {
                let j = consumeBlockComment(u, i, end, BlockComment("/*", "*/"))
                tokens.append(Token(type: .comment, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if matches(u, i, end, "//") {
                var j = i
                while j < end && u[j] != 0x0A { j += 1 }
                tokens.append(Token(type: .comment, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if c == UInt16(ascii: "\"") || c == UInt16(ascii: "'") {
                i = consumeString(u, i, end, StringRule(open: String(UnicodeScalar(UInt8(c)))), &tokens)
                continue
            }
            if c == UInt16(ascii: "@") {
                var j = i + 1
                while j < end && (isLetter(u[j]) || u[j] == UInt16(ascii: "-")) { j += 1 }
                tokens.append(Token(type: .keyword, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if c == UInt16(ascii: "$") || c == UInt16(ascii: "-") && matches(u, i, end, "--") {
                var j = i + 1
                while j < end && (isLetter(u[j]) || isDigit(u[j]) || u[j] == UInt16(ascii: "-") || u[j] == UInt16(ascii: "_")) { j += 1 }
                tokens.append(Token(type: .variable, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if c == UInt16(ascii: "#") && i + 1 < end && isHexDigit(u[i + 1]) && inBlock {
                var j = i + 1
                while j < end && isHexDigit(u[j]) { j += 1 }
                tokens.append(Token(type: .number, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if isDigit(c) || (c == UInt16(ascii: ".") && i + 1 < end && isDigit(u[i + 1])) {
                let j = consumeNumber(u, i, end, lang)
                tokens.append(Token(type: .number, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if c == UInt16(ascii: "{") { inBlock = true; afterColon = false
                tokens.append(Token(type: .punctuation, range: NSRange(location: i, length: 1))); i += 1; continue }
            if c == UInt16(ascii: "}") { inBlock = false; afterColon = false
                tokens.append(Token(type: .punctuation, range: NSRange(location: i, length: 1))); i += 1; continue }
            if c == UInt16(ascii: ":") { afterColon = true
                tokens.append(Token(type: .punctuation, range: NSRange(location: i, length: 1))); i += 1; continue }
            if c == UInt16(ascii: ";") { afterColon = false
                tokens.append(Token(type: .punctuation, range: NSRange(location: i, length: 1))); i += 1; continue }
            if isLetter(c) || c == UInt16(ascii: "_") || c == UInt16(ascii: "-") || c == UInt16(ascii: ".")
                || c == UInt16(ascii: "#") || c == UInt16(ascii: "&") {
                var j = i + 1
                while j < end && (isLetter(u[j]) || isDigit(u[j]) || u[j] == UInt16(ascii: "-")
                                  || u[j] == UInt16(ascii: "_")) { j += 1 }
                let type: TokenType
                if inBlock && !afterColon { type = .property }
                else if inBlock { type = nextNonSpace(u, j, end) == UInt16(ascii: "(") ? .function : .constant }
                else { type = .tag }
                tokens.append(Token(type: type, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            tokens.append(Token(type: .operator, range: NSRange(location: i, length: 1)))
            i += 1
        }
    }

    // MARK: - Markdown

    private func scanMarkdown(_ u: [unichar], _ start: Int, _ end: Int,
                              _ lang: LanguageDefinition, _ tokens: inout [Token]) {
        var i = start
        while i < end {
            let lineStart = i
            var lineEnd = i
            while lineEnd < end && u[lineEnd] != 0x0A { lineEnd += 1 }
            let line = NSRange(location: lineStart, length: lineEnd - lineStart)

            var p = lineStart
            while p < lineEnd && (u[p] == UInt16(ascii: " ") || u[p] == UInt16(ascii: "\t")) { p += 1 }

            if matches(u, p, lineEnd, "```") || matches(u, p, lineEnd, "~~~") {
                let fence = String(utf16CodeUnits: [u[p], u[p], u[p]], count: 3)
                var info = p + 3
                while info < lineEnd && isSpace(u[info]) { info += 1 }
                var infoEnd = info
                while infoEnd < lineEnd && !isSpace(u[infoEnd]) { infoEnd += 1 }
                let langName = String(utf16CodeUnits: Array(u[info..<max(info, infoEnd)]),
                                      count: max(0, infoEnd - info))
                tokens.append(Token(type: .keyword, range: line))
                // find closing fence
                var body = lineEnd < end ? lineEnd + 1 : end
                let bodyStart = body
                var closeLineStart = end
                while body < end {
                    var ls = body
                    while ls < end && isSpace(u[ls]) && u[ls] != 0x0A { ls += 1 }
                    if matches(u, ls, end, fence) { closeLineStart = body; break }
                    while body < end && u[body] != 0x0A { body += 1 }
                    if body < end { body += 1 }
                }
                let codeEnd = min(closeLineStart, end)
                if codeEnd > bodyStart {
                    if let embedded = LanguageRegistry.shared.language(named: langName), embedded.flavor != .plain {
                        scan(u, from: bodyStart, to: codeEnd, language: embedded, into: &tokens)
                    } else {
                        tokens.append(Token(type: .string, range: NSRange(location: bodyStart, length: codeEnd - bodyStart)))
                    }
                }
                i = codeEnd
                if i < end {
                    var le = i
                    while le < end && u[le] != 0x0A { le += 1 }
                    tokens.append(Token(type: .keyword, range: NSRange(location: i, length: le - i)))
                    i = le < end ? le + 1 : end
                }
                continue
            }

            if p < lineEnd && u[p] == UInt16(ascii: "#") {
                tokens.append(Token(type: .heading, range: line))
            } else if p < lineEnd && u[p] == UInt16(ascii: ">") {
                tokens.append(Token(type: .comment, range: line))
            } else if p + 1 < lineEnd && (u[p] == UInt16(ascii: "-") || u[p] == UInt16(ascii: "*")
                                          || u[p] == UInt16(ascii: "+")) && isSpace(u[p + 1]) {
                tokens.append(Token(type: .keyword, range: NSRange(location: p, length: 1)))
                scanMarkdownInline(u, p + 1, lineEnd, &tokens)
            } else {
                scanMarkdownInline(u, p, lineEnd, &tokens)
            }
            i = lineEnd < end ? lineEnd + 1 : end
        }
    }

    private func scanMarkdownInline(_ u: [unichar], _ start: Int, _ end: Int, _ tokens: inout [Token]) {
        var i = start
        while i < end {
            let c = u[i]
            if c == UInt16(ascii: "`") {
                var j = i + 1
                while j < end && u[j] != UInt16(ascii: "`") { j += 1 }
                j = min(end, j + 1)
                tokens.append(Token(type: .string, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if matches(u, i, end, "**") || matches(u, i, end, "__") {
                let marker = String(utf16CodeUnits: [u[i], u[i]], count: 2)
                var j = i + 2
                while j < end && !matches(u, j, end, marker) { j += 1 }
                j = min(end, j + 2)
                tokens.append(Token(type: .strong, range: NSRange(location: i, length: j - i)))
                i = j
                continue
            }
            if c == UInt16(ascii: "*") || c == UInt16(ascii: "_") {
                var j = i + 1
                while j < end && u[j] != c { j += 1 }
                if j < end {
                    tokens.append(Token(type: .emphasis, range: NSRange(location: i, length: j - i + 1)))
                    i = j + 1
                    continue
                }
            }
            if c == UInt16(ascii: "[") {
                var j = i + 1
                while j < end && u[j] != UInt16(ascii: "]") { j += 1 }
                if j + 1 < end && u[j + 1] == UInt16(ascii: "(") {
                    var k = j + 2
                    while k < end && u[k] != UInt16(ascii: ")") { k += 1 }
                    k = min(end, k + 1)
                    tokens.append(Token(type: .link, range: NSRange(location: i, length: j - i + 1)))
                    tokens.append(Token(type: .string, range: NSRange(location: j + 1, length: k - j - 1)))
                    i = k
                    continue
                }
            }
            i += 1
        }
    }

    // MARK: - INI / TOML-ish / conf

    private func scanINI(_ u: [unichar], _ start: Int, _ end: Int,
                         _ lang: LanguageDefinition, _ tokens: inout [Token]) {
        var i = start
        while i < end {
            var lineEnd = i
            while lineEnd < end && u[lineEnd] != 0x0A { lineEnd += 1 }
            var p = i
            while p < lineEnd && isSpace(u[p]) { p += 1 }
            if p < lineEnd && (u[p] == UInt16(ascii: "#") || u[p] == UInt16(ascii: ";")) {
                tokens.append(Token(type: .comment, range: NSRange(location: p, length: lineEnd - p)))
            } else if p < lineEnd && u[p] == UInt16(ascii: "[") {
                tokens.append(Token(type: .heading, range: NSRange(location: p, length: lineEnd - p)))
            } else {
                var eq = p
                while eq < lineEnd && u[eq] != UInt16(ascii: "=") && u[eq] != UInt16(ascii: ":") { eq += 1 }
                if eq < lineEnd {
                    tokens.append(Token(type: .property, range: NSRange(location: p, length: eq - p)))
                    tokens.append(Token(type: .operator, range: NSRange(location: eq, length: 1)))
                    var v = eq + 1
                    while v < lineEnd && isSpace(u[v]) { v += 1 }
                    if v < lineEnd {
                        let vt: TokenType = isDigit(u[v]) ? .number
                            : (u[v] == UInt16(ascii: "\"") || u[v] == UInt16(ascii: "'")) ? .string : .constant
                        tokens.append(Token(type: vt, range: NSRange(location: v, length: lineEnd - v)))
                    }
                }
            }
            i = lineEnd < end ? lineEnd + 1 : end
        }
    }

    // MARK: - Diff / patch

    private func scanDiff(_ u: [unichar], _ start: Int, _ end: Int, _ tokens: inout [Token]) {
        var i = start
        while i < end {
            var lineEnd = i
            while lineEnd < end && u[lineEnd] != 0x0A { lineEnd += 1 }
            let range = NSRange(location: i, length: lineEnd - i)
            if range.length > 0 {
                switch u[i] {
                case UInt16(ascii: "+"):
                    tokens.append(Token(type: matches(u, i, end, "+++") ? .heading : .inserted, range: range))
                case UInt16(ascii: "-"):
                    tokens.append(Token(type: matches(u, i, end, "---") ? .heading : .deleted, range: range))
                case UInt16(ascii: "@"):
                    tokens.append(Token(type: .keyword, range: range))
                case UInt16(ascii: "d"), UInt16(ascii: "i"), UInt16(ascii: "n"):
                    tokens.append(Token(type: .heading, range: range))
                default:
                    break
                }
            }
            i = lineEnd < end ? lineEnd + 1 : end
        }
    }

    // MARK: - Regex rules

    private func applyRegexRules(text: String, units: [unichar], region: NSRange,
                                 language lang: LanguageDefinition, tokens: inout [Token]) {
        guard !lang.rules.isEmpty else { return }
        let protectedRanges = tokens.filter {
            $0.type == .string || $0.type == .comment || $0.type == .docComment || $0.type == .regex
        }.map { $0.range }

        for rule in lang.rules {
            guard let regex = RegexCache.shared.regex(rule.pattern, rule.options) else { continue }
            regex.enumerateMatches(in: text, options: [], range: region) { match, _, _ in
                guard let match, rule.group < match.numberOfRanges else { return }
                let r = match.range(at: rule.group)
                guard r.location != NSNotFound, r.length > 0 else { return }
                for p in protectedRanges where NSIntersectionRange(p, r).length > 0 { return }
                tokens.removeAll { NSIntersectionRange($0.range, r).length > 0 && $0.type != .string && $0.type != .comment }
                tokens.append(Token(type: rule.type, range: r))
            }
        }
    }

    // MARK: - Character helpers

    private func matches(_ u: [unichar], _ i: Int, _ end: Int, _ s: String) -> Bool {
        let pattern = Array(s.utf16)
        guard i + pattern.count <= end else { return false }
        for k in 0..<pattern.count where u[i + k] != pattern[k] { return false }
        return true
    }

    private func nextNonSpace(_ u: [unichar], _ i: Int, _ end: Int) -> unichar {
        var j = i
        while j < end && (u[j] == UInt16(ascii: " ") || u[j] == UInt16(ascii: "\t")) { j += 1 }
        return j < end ? u[j] : 0
    }

    private func isSpace(_ c: unichar) -> Bool {
        c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
    }
    private func isDigit(_ c: unichar) -> Bool { c >= 0x30 && c <= 0x39 }
    private func isHexDigit(_ c: unichar) -> Bool {
        isDigit(c) || ((c | 0x20) >= UInt16(ascii: "a") && (c | 0x20) <= UInt16(ascii: "f"))
    }
    private func isLetter(_ c: unichar) -> Bool {
        (c | 0x20) >= UInt16(ascii: "a") && (c | 0x20) <= UInt16(ascii: "z")
    }
    private func isIdentifierStart(_ c: unichar, _ lang: LanguageDefinition) -> Bool {
        if isLetter(c) || c >= 0x80 { return true }
        guard let s = UnicodeScalar(c) else { return false }
        return lang.identifierStartExtras.contains(Character(s))
    }
    private func isIdentifierPart(_ c: unichar, _ lang: LanguageDefinition) -> Bool {
        if isLetter(c) || isDigit(c) || c >= 0x80 { return true }
        guard let s = UnicodeScalar(c) else { return false }
        return lang.identifierExtras.contains(Character(s))
    }
    /// Heuristic used when a language has no type list: `FooBar` / `NSString`.
    private func isTypeShaped(_ word: String) -> Bool {
        guard word.count > 1, let first = word.first, first.isUppercase else { return false }
        return word.dropFirst().contains(where: { $0.isLowercase })
    }
}

/// Compiled regexes are cached; recompiling per keystroke is far too slow.
final class RegexCache {
    static let shared = RegexCache()
    private var cache: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(_ pattern: String, _ options: NSRegularExpression.Options) -> NSRegularExpression? {
        let key = "\(options.rawValue)|\(pattern)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        cache[key] = regex
        return regex
    }
}
