import UIKit

/// Builds the HTML that the preview loads for everything the web engine can
/// render directly (as opposed to the bundled language runtimes, which have
/// their own pages).
enum PreviewPage {

    static func html(for document: CodeDocument, kind: PreviewKind, theme: EditorTheme) -> String {
        let source = document.text
        switch kind {
        case .html:
            return source
        case .svg:
            return page(body: source, theme: theme,
                        extraCSS: "svg { max-width: 100%; height: auto; }")
        case .markdown:
            return page(body: MarkdownRenderer.html(from: source, theme: theme), theme: theme)
        case .css:
            return page(body: cssSampleBody, theme: theme, extraCSS: source)
        case .javascript:
            return page(body: "<div id=\"cf-output\"></div>", theme: theme, script: source,
                        extraCSS: "#cf-output:empty::before { content: '\(L("Script ran. Output goes to the console."))'; color: var(--muted); }")
        case .json:
            return page(body: jsonBody(source, theme: theme), theme: theme)
        case .runtime, .unsupported:
            return page(body: "", theme: theme)
        }
    }

    static func message(title: String, theme: EditorTheme) -> String {
        page(body: "<p class=\"bad\">\(MarkdownRenderer.escape(title))</p>", theme: theme)
    }

    private static var cssSampleBody: String {
        """
        <h1>見出し 1 / Heading 1</h1>
        <h2>見出し 2 / Heading 2</h2>
        <p>本文のサンプルです。<a href="#">リンク</a>、<strong>太字</strong>、<em>斜体</em>、<code>inline code</code>。</p>
        <p><button>ボタン</button> <input placeholder="入力欄"></p>
        <ul><li>リスト項目</li><li>リスト項目</li></ul>
        <table><thead><tr><th>列 A</th><th>列 B</th></tr></thead>
        <tbody><tr><td>1</td><td>2</td></tr></tbody></table>
        <blockquote>引用ブロック</blockquote>
        <div class="card box container">クラス付きの要素（.card / .box / .container）</div>
        """
    }

    private static func jsonBody(_ source: String, theme: EditorTheme) -> String {
        guard let data = source.data(using: .utf8) else { return "" }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let pretty = try JSONSerialization.data(withJSONObject: object,
                                                    options: [.prettyPrinted, .sortedKeys,
                                                              .withoutEscapingSlashes])
            let text = String(data: pretty, encoding: .utf8) ?? source
            let json = LanguageRegistry.shared.language(id: "json") ?? LanguageRegistry.plainText
            let highlighted = MarkdownRenderer.highlighted(text, language: json, theme: theme)
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            return """
            <p class="ok">✓ \(L("Valid JSON")) — \(size)</p>
            <pre><code>\(highlighted)</code></pre>
            """
        } catch {
            return """
            <p class="bad">✗ \(L("Invalid JSON"))</p>
            <pre class="bad"><code>\(MarkdownRenderer.escape(error.localizedDescription))</code></pre>
            <pre><code>\(MarkdownRenderer.escape(source))</code></pre>
            """
        }
    }

    /// Wraps generated content in a page themed like the editor.
    static func page(body: String, theme: EditorTheme,
                     script: String = "", extraCSS: String = "") -> String {
        """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root {
          --bg: \(theme.background.cssColor);
          --fg: \(theme.foreground.cssColor);
          --muted: \(theme.gutterForeground.cssColor);
          --accent: \(theme.accent.cssColor);
          --line: \(theme.indentGuide.cssColor);
          --surface: \(theme.currentLine.cssColor);
        }
        * { box-sizing: border-box; }
        body {
          margin: 0; padding: 18px 16px 40px;
          background: var(--bg); color: var(--fg);
          font: 16px/1.75 -apple-system, "Hiragino Sans", system-ui, sans-serif;
          -webkit-text-size-adjust: 100%;
        }
        h1, h2, h3, h4, h5, h6 { line-height: 1.35; margin: 1.6em 0 .6em; }
        h1 { font-size: 1.7em; border-bottom: 1px solid var(--line); padding-bottom: .3em; }
        h2 { font-size: 1.4em; border-bottom: 1px solid var(--line); padding-bottom: .25em; }
        h3 { font-size: 1.2em; }
        p, ul, ol, table, blockquote, figure { margin: 0 0 1em; }
        a { color: var(--accent); }
        code { font-family: ui-monospace, Menlo, monospace; font-size: .88em;
               background: var(--surface); padding: .15em .35em; border-radius: 4px; }
        pre { background: var(--surface); padding: 12px 14px; border-radius: 10px;
              overflow-x: auto; border: 1px solid var(--line); }
        pre code { background: none; padding: 0; font-size: .85em; line-height: 1.6; }
        figure.code { margin: 0 0 1.2em; }
        figure.code figcaption { font-size: .72em; color: var(--muted);
              padding: 0 0 4px 2px; text-transform: uppercase; letter-spacing: .04em; }
        blockquote { margin-left: 0; padding: .1em 1em; border-left: 3px solid var(--accent);
              color: var(--muted); }
        table { border-collapse: collapse; width: 100%; display: block; overflow-x: auto; }
        th, td { border: 1px solid var(--line); padding: 6px 10px; }
        th { background: var(--surface); }
        hr { border: none; border-top: 1px solid var(--line); margin: 2em 0; }
        img { max-width: 100%; height: auto; border-radius: 6px; }
        li.task { list-style: none; margin-left: -1.2em; }
        .ok { color: #3fb950; } .bad { color: #f85149; }
        \(extraCSS)
        </style>
        </head>
        <body>
        \(body)
        <script>\(script)</script>
        </body>
        </html>
        """
    }
}
