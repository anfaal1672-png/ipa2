import UIKit

/// Markdown → HTML, written against CommonMark's common subset plus the
/// GitHub extensions people actually use (tables, task lists, strikethrough,
/// autolinks). Fenced code blocks are coloured with the editor's own scanner,
/// so a preview looks like the editor rather than like plain grey text.
enum MarkdownRenderer {

    static func html(from markdown: String, theme: EditorTheme) -> String {
        var lines = markdown.components(separatedBy: .newlines)
        var out = ""
        var index = 0

        // Reference-style link definitions: [id]: url "title"
        var references: [String: String] = [:]
        for line in lines {
            if let match = line.range(of: #"^\s*\[([^\]]+)\]:\s*(\S+)"#, options: .regularExpression) {
                let text = String(line[match])
                if let idRange = text.range(of: #"\[([^\]]+)\]"#, options: .regularExpression),
                   let urlRange = text.range(of: #":\s*(\S+)"#, options: .regularExpression) {
                    let id = String(text[idRange]).dropFirst().dropLast().lowercased()
                    let url = String(text[urlRange]).dropFirst().trimmingCharacters(in: .whitespaces)
                    // Escaped here because it is spliced into href="…" later,
                    // and unlike inline links this text never passes through
                    // `escape`: a URL holding a quote broke out of the
                    // attribute and swallowed the rest of the tag.
                    references[String(id)] = escape(url)
                }
            }
        }

        func inline(_ text: String) -> String { renderInline(text, references: references) }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // fenced code
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let fence = String(trimmed.prefix(3))
                let info = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if candidate.hasPrefix(fence) { break }
                    body.append(lines[index])
                    index += 1
                }
                index += 1
                let code = body.joined(separator: "\n")
                let language = LanguageRegistry.shared.language(named: info)
                let rendered = language.map { highlighted(code, language: $0, theme: theme) }
                    ?? escape(code)
                let label = language?.name ?? (info.isEmpty ? "" : escape(info))
                out += "<figure class=\"code\">"
                if !label.isEmpty { out += "<figcaption>\(label)</figcaption>" }
                out += "<pre><code>\(rendered)</code></pre></figure>\n"
                continue
            }

            // headings
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                if hashes <= 6, trimmed.count > hashes {
                    let content = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                    let anchor = slug(content)
                    out += "<h\(hashes) id=\"\(anchor)\">\(inline(content))</h\(hashes)>\n"
                    index += 1
                    continue
                }
            }

            // horizontal rule
            if trimmed.range(of: #"^(\*\s*){3,}$|^(-\s*){3,}$|^(_\s*){3,}$"#,
                             options: .regularExpression) != nil {
                out += "<hr>\n"
                index += 1
                continue
            }

            // table
            if index + 1 < lines.count,
               trimmed.contains("|"),
               lines[index + 1].trimmingCharacters(in: .whitespaces)
                   .range(of: #"^\|?[\s:|-]+\|[\s:|-]*$"#, options: .regularExpression) != nil {
                let header = splitRow(trimmed)
                let alignments = splitRow(lines[index + 1]).map { spec -> String in
                    let s = spec.trimmingCharacters(in: .whitespaces)
                    if s.hasPrefix(":") && s.hasSuffix(":") { return "center" }
                    if s.hasSuffix(":") { return "right" }
                    return "left"
                }
                index += 2
                out += "<table><thead><tr>"
                for (i, cell) in header.enumerated() {
                    let align = i < alignments.count ? alignments[i] : "left"
                    out += "<th style=\"text-align:\(align)\">\(inline(cell))</th>"
                }
                out += "</tr></thead><tbody>"
                while index < lines.count,
                      lines[index].contains("|"),
                      !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    let cells = splitRow(lines[index])
                    out += "<tr>"
                    for (i, cell) in cells.enumerated() {
                        let align = i < alignments.count ? alignments[i] : "left"
                        out += "<td style=\"text-align:\(align)\">\(inline(cell))</td>"
                    }
                    out += "</tr>"
                    index += 1
                }
                out += "</tbody></table>\n"
                continue
            }

            // block quote
            if trimmed.hasPrefix(">") {
                var body: [String] = []
                while index < lines.count,
                      lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    var stripped = lines[index].trimmingCharacters(in: .whitespaces)
                    stripped.removeFirst()
                    body.append(stripped.hasPrefix(" ") ? String(stripped.dropFirst()) : stripped)
                    index += 1
                }
                out += "<blockquote>\(html(from: body.joined(separator: "\n"), theme: theme))</blockquote>\n"
                continue
            }

            // lists (nested, ordered and task lists)
            if isListItem(trimmed) {
                let (rendered, next) = renderList(lines, from: index, references: references)
                out += rendered
                index = next
                continue
            }

            // reference definition — already collected
            if trimmed.range(of: #"^\[([^\]]+)\]:\s*\S+"#, options: .regularExpression) != nil {
                index += 1
                continue
            }

            // blank
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // paragraph: gather until a blank line or a block starter
            var paragraph: [String] = []
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty || candidate.hasPrefix("#") || candidate.hasPrefix(">")
                    || candidate.hasPrefix("```") || candidate.hasPrefix("~~~") || isListItem(candidate) {
                    break
                }
                paragraph.append(lines[index])
                index += 1
            }
            let joined = paragraph
                .map { $0.hasSuffix("  ") ? $0.trimmingCharacters(in: .whitespaces) + "<br>" : $0 }
                .joined(separator: "\n")
            out += "<p>\(inline(joined))</p>\n"
        }

        lines.removeAll()
        return out
    }

    // MARK: - Lists

    private static func isListItem(_ trimmed: String) -> Bool {
        trimmed.range(of: #"^([-*+]|\d+[.)])\s+"#, options: .regularExpression) != nil
    }

    private static func indentWidth(_ line: String) -> Int {
        var width = 0
        for character in line {
            if character == " " { width += 1 }
            else if character == "\t" { width += 4 }
            else { break }
        }
        return width
    }

    private static func renderList(_ lines: [String], from start: Int,
                                   references: [String: String]) -> (String, Int) {
        let baseIndent = indentWidth(lines[start])
        let firstTrimmed = lines[start].trimmingCharacters(in: .whitespaces)
        let ordered = firstTrimmed.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
        var out = ordered ? "<ol>\n" : "<ul>\n"
        var index = start

        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                // a blank line ends the list unless the next line continues it
                if index + 1 < lines.count, isListItem(lines[index + 1].trimmingCharacters(in: .whitespaces)),
                   indentWidth(lines[index + 1]) >= baseIndent {
                    index += 1
                    continue
                }
                break
            }
            let indent = indentWidth(raw)
            if indent < baseIndent || !isListItem(trimmed) { break }

            if indent > baseIndent {
                let (nested, next) = renderList(lines, from: index, references: references)
                out += nested
                index = next
                continue
            }

            var content = trimmed.replacingOccurrences(of: #"^([-*+]|\d+[.)])\s+"#, with: "",
                                                       options: .regularExpression)
            var classes = ""
            if content.lowercased().hasPrefix("[ ] ") {
                content = String(content.dropFirst(4))
                classes = " class=\"task\""
                content = "<input type=\"checkbox\" disabled> " + content
            } else if content.lowercased().hasPrefix("[x] ") {
                content = String(content.dropFirst(4))
                classes = " class=\"task\""
                content = "<input type=\"checkbox\" checked disabled> " + content
            }
            out += "<li\(classes)>\(renderInline(content, references: references))"

            // continuation lines and nested lists
            index += 1
            while index < lines.count {
                let nextRaw = lines[index]
                let nextTrimmed = nextRaw.trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty { break }
                let nextIndent = indentWidth(nextRaw)
                if isListItem(nextTrimmed), nextIndent > baseIndent {
                    let (nested, next) = renderList(lines, from: index, references: references)
                    out += nested
                    index = next
                    continue
                }
                if isListItem(nextTrimmed) || nextIndent < baseIndent { break }
                out += " " + renderInline(nextTrimmed, references: references)
                index += 1
            }
            out += "</li>\n"
        }

        out += ordered ? "</ol>\n" : "</ul>\n"
        return (out, index)
    }

    private static func splitRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Inline

    private static func renderInline(_ text: String, references: [String: String]) -> String {
        var result = escape(text)

        // inline code first, so nothing inside it gets further formatting
        var codeSpans: [String] = []
        result = replace(result, pattern: "`([^`]+)`") { groups in
            codeSpans.append(groups[1])
            return "\u{0}CODE\(codeSpans.count - 1)\u{0}"
        }

        // images then links
        result = replace(result, pattern: #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)"#) { groups in
            "<img src=\"\(groups[2])\" alt=\"\(groups[1])\">"
        }
        result = replace(result, pattern: #"\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)"#) { groups in
            "<a href=\"\(groups[2])\">\(groups[1])</a>"
        }
        result = replace(result, pattern: #"\[([^\]]+)\]\[([^\]]*)\]"#) { groups in
            let key = (groups[2].isEmpty ? groups[1] : groups[2]).lowercased()
            guard let url = references[key] else { return "[\(groups[1])]" }
            return "<a href=\"\(url)\">\(groups[1])</a>"
        }

        result = replace(result, pattern: #"(\*\*\*|___)(.+?)\1"#) { g in "<strong><em>\(g[2])</em></strong>" }
        result = replace(result, pattern: #"(\*\*|__)(.+?)\1"#) { g in "<strong>\(g[2])</strong>" }
        result = replace(result, pattern: #"(?<![\w*])\*([^*\n]+)\*(?![\w*])"#) { g in "<em>\(g[1])</em>" }
        result = replace(result, pattern: #"(?<![\w_])_([^_\n]+)_(?![\w_])"#) { g in "<em>\(g[1])</em>" }
        result = replace(result, pattern: "~~(.+?)~~") { g in "<del>\(g[1])</del>" }
        result = replace(result, pattern: #"(?<![">=\w])(https?://[^\s<)]+)"#) { g in
            "<a href=\"\(g[1])\">\(g[1])</a>"
        }

        for (i, code) in codeSpans.enumerated() {
            result = result.replacingOccurrences(of: "\u{0}CODE\(i)\u{0}", with: "<code>\(code)</code>")
        }
        return result
    }

    private static func replace(_ text: String, pattern: String,
                                _ transform: ([String]) -> String) -> String {
        guard let regex = RegexCache.shared.regex(pattern, []) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let r = match.range(at: i)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += transform(groups)
            last = NSMaxRange(match.range)
        }
        result += ns.substring(from: last)
        return result
    }

    private static func slug(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = text.lowercased().unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(cleaned)).replacingOccurrences(of: " ", with: "-")
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Runs the editor's scanner over a code block and wraps tokens in spans.
    static func highlighted(_ code: String, language: LanguageDefinition, theme: EditorTheme) -> String {
        let tokens = SyntaxScanner(language: language).tokenize(code)
        let ns = code as NSString
        var result = ""
        var cursor = 0
        for token in tokens.sorted(by: { $0.range.location < $1.range.location }) {
            guard token.range.location >= cursor else { continue }
            if token.range.location > cursor {
                result += escape(ns.substring(with: NSRange(location: cursor,
                                                            length: token.range.location - cursor)))
            }
            let piece = escape(ns.substring(with: token.range))
            result += "<span style=\"color:\(theme.color(for: token.type).cssColor)\">\(piece)</span>"
            cursor = NSMaxRange(token.range)
        }
        if cursor < ns.length {
            result += escape(ns.substring(from: cursor))
        }
        return result
    }
}

extension UIColor {
    /// `#rrggbb` for embedding in generated HTML.
    var cssColor: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
