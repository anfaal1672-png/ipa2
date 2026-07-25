import SwiftUI
import WebKit

/// What the preview can do with a given file.
enum PreviewKind {
    case html            // rendered in place, scripts and all
    case markdown        // converted to HTML, code blocks coloured
    case svg
    case css             // applied to a sample page
    case javascript      // executed, console output captured
    case json            // validated and pretty printed
    case unsupported

    static func kind(for language: LanguageDefinition) -> PreviewKind {
        switch language.id {
        case "html", "xml", "vue", "svelte", "erb", "jinja", "blade": return .html
        case "markdown": return .markdown
        case "css", "scss", "less", "stylus": return .css
        case "javascript", "typescript", "jsx", "tsx": return .javascript
        case "json", "jsonc": return .json
        default:
            return language.extensions.contains("svg") ? .svg : .unsupported
        }
    }

    var canRun: Bool { self != .unsupported }
}

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let level: String
    let text: String
    let date = Date()

    var color: Color {
        switch level {
        case "error": return .red
        case "warn": return .orange
        case "info": return .blue
        default: return .primary
        }
    }

    var icon: String {
        switch level {
        case "error": return "xmark.octagon.fill"
        case "warn": return "exclamationmark.triangle.fill"
        default: return "chevron.right"
        }
    }
}

/// Live preview: renders (and for HTML/JS actually *runs*) the open file.
struct PreviewView: View {

    @ObservedObject var document: CodeDocument
    let theme: EditorTheme
    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ConsoleMessage] = []
    @State private var showConsole = false
    @State private var reloadToken = 0
    @State private var autoRefresh = true
    @State private var isLoading = false
    @State private var pageTitle = ""

    private var kind: PreviewKind { PreviewKind.kind(for: document.language) }

    private var errorCount: Int { messages.filter { $0.level == "error" }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if kind == .unsupported {
                    unsupportedState
                } else {
                    WebPreview(html: renderedHTML,
                               baseDirectory: document.url?.deletingLastPathComponent(),
                               reloadToken: reloadToken,
                               onConsole: { messages.append($0) },
                               onLoadingChange: { isLoading = $0 },
                               onTitleChange: { pageTitle = $0 })
                        .background(Color(theme.background))
                }

                if showConsole {
                    Divider()
                    consolePanel
                }
            }
            .navigationTitle(pageTitle.isEmpty ? document.name : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Done")) { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if isLoading { ProgressView().controlSize(.small) }

                    Button {
                        messages.removeAll()
                        reloadToken += 1
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(L("Reload"))

                    Button {
                        showConsole.toggle()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "terminal")
                            if errorCount > 0 {
                                Circle().fill(Color.red).frame(width: 7, height: 7).offset(x: 5, y: -3)
                            } else if !messages.isEmpty {
                                Circle().fill(Color(theme.accent)).frame(width: 7, height: 7).offset(x: 5, y: -3)
                            }
                        }
                    }
                    .accessibilityLabel(L("Console"))

                    Menu {
                        Toggle(L("Reload when the file changes"), isOn: $autoRefresh)
                        Button {
                            messages.removeAll()
                        } label: { Label(L("Clear console"), systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onChange(of: document.revision) { _ in
                if autoRefresh { reloadToken += 1 }
            }
        }
    }

    // MARK: - Console

    private var consolePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("Console"))
                    .font(.caption.weight(.semibold))
                Text("\(messages.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Button(L("Clear console")) { messages.removeAll() }
                    .font(.caption)
                Button {
                    showConsole = false
                } label: { Image(systemName: "chevron.down") }
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if messages.isEmpty {
                Text(L("No console output"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(messages) { message in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: message.icon)
                                        .font(.system(size: 9))
                                        .foregroundColor(message.color)
                                        .padding(.top, 2)
                                    Text(message.text)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(message.color)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { scrollProxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .frame(height: 190)
        .background(Color(theme.gutterBackground))
    }

    private var unsupportedState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "eye.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            Text(L("This file type cannot be previewed"))
                .font(.headline)
            Text(L("HTML, Markdown, CSS, JavaScript, JSON and SVG can be previewed. Other languages need a compiler or runtime that iOS does not allow apps to ship."))
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rendering

    private var renderedHTML: String {
        let source = document.text
        switch kind {
        case .html:
            return source
        case .svg:
            return page(body: source, extraCSS: "svg { max-width: 100%; height: auto; }")
        case .markdown:
            return page(body: MarkdownRenderer.html(from: source, theme: theme))
        case .css:
            return page(body: cssSampleBody, extraCSS: source)
        case .javascript:
            return page(body: "<div id=\"cf-output\"></div>",
                        script: source,
                        extraCSS: "#cf-output:empty::before { content: '\(L("Script ran. Output goes to the console."))'; color: var(--muted); }")
        case .json:
            return page(body: jsonBody(source))
        case .unsupported:
            return page(body: "")
        }
    }

    private var cssSampleBody: String {
        """
        <h1>見出し 1 / Heading 1</h1>
        <h2>見出し 2 / Heading 2</h2>
        <p>本文のサンプルです。<a href="#">リンク</a>、<strong>太字</strong>、<em>斜体</em>、<code>inline code</code>。</p>
        <button>ボタン</button> <input placeholder="入力欄">
        <ul><li>リスト項目</li><li>リスト項目</li></ul>
        <table><thead><tr><th>列 A</th><th>列 B</th></tr></thead>
        <tbody><tr><td>1</td><td>2</td></tr></tbody></table>
        <blockquote>引用ブロック</blockquote>
        <div class="card box container">クラス付きの要素（.card / .box / .container）</div>
        """
    }

    private func jsonBody(_ source: String) -> String {
        guard let data = source.data(using: .utf8) else { return "" }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let pretty = try JSONSerialization.data(withJSONObject: object,
                                                    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            let text = String(data: pretty, encoding: .utf8) ?? source
            let json = LanguageRegistry.shared.language(id: "json") ?? LanguageRegistry.plainText
            let highlighted = MarkdownRenderer.highlighted(text, language: json, theme: theme)
            return """
            <p class="ok">✓ \(L("Valid JSON")) — \(byteCount(data.count))</p>
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

    private func byteCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// Wraps generated content in a page themed like the editor.
    private func page(body: String, script: String = "", extraCSS: String = "") -> String {
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

// MARK: - WKWebView wrapper

private struct WebPreview: UIViewRepresentable {

    let html: String
    let baseDirectory: URL?
    let reloadToken: Int
    let onConsole: (ConsoleMessage) -> Void
    let onLoadingChange: (Bool) -> Void
    let onTitleChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onConsole: onConsole, onLoadingChange: onLoadingChange, onTitleChange: onTitleChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "codeforge")
        controller.addUserScript(WKUserScript(source: Coordinator.consoleShim,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive
        context.coordinator.load(html: html, baseDirectory: baseDirectory, into: webView)
        context.coordinator.lastToken = reloadToken
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastToken != reloadToken else { return }
        context.coordinator.lastToken = reloadToken
        context.coordinator.load(html: html, baseDirectory: baseDirectory, into: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cleanUp()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "codeforge")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

        /// Mirrors console output and uncaught errors back into the app, which
        /// is the part that makes this a developer preview rather than a viewer.
        static let consoleShim = """
        (function () {
          function stringify(value) {
            try {
              if (value instanceof Error) { return value.stack || (value.name + ': ' + value.message); }
              if (typeof value === 'object' && value !== null) { return JSON.stringify(value); }
              return String(value);
            } catch (e) { return String(value); }
          }
          function send(level, args) {
            try {
              window.webkit.messageHandlers.codeforge.postMessage({
                level: level,
                text: Array.prototype.map.call(args, stringify).join(' ')
              });
            } catch (e) {}
          }
          ['log', 'info', 'warn', 'error', 'debug'].forEach(function (level) {
            var original = console[level] ? console[level].bind(console) : function () {};
            console[level] = function () { send(level, arguments); original.apply(console, arguments); };
          });
          window.addEventListener('error', function (event) {
            send('error', [event.message + '  (' + (event.filename || 'inline') + ':' + event.lineno + ')']);
          });
          window.addEventListener('unhandledrejection', function (event) {
            send('error', ['Unhandled promise rejection: ' + stringify(event.reason)]);
          });
        })();
        """

        private let onConsole: (ConsoleMessage) -> Void
        private let onLoadingChange: (Bool) -> Void
        private let onTitleChange: (String) -> Void
        var lastToken = -1
        private var temporaryFile: URL?

        init(onConsole: @escaping (ConsoleMessage) -> Void,
             onLoadingChange: @escaping (Bool) -> Void,
             onTitleChange: @escaping (String) -> Void) {
            self.onConsole = onConsole
            self.onLoadingChange = onLoadingChange
            self.onTitleChange = onTitleChange
        }

        /// Loading from a file *beside the original* is what makes relative
        /// paths work: `<img src="logo.png">` and `<link href="style.css">`
        /// resolve against the user's own folder. Without a folder to write
        /// into (an unsaved buffer) we fall back to an in-memory load, where
        /// relative resources cannot resolve.
        func load(html: String, baseDirectory: URL?, into webView: WKWebView) {
            onLoadingChange(true)
            guard let directory = baseDirectory,
                  FileManager.default.isWritableFile(atPath: directory.path) else {
                webView.loadHTMLString(html, baseURL: nil)
                return
            }
            let target = directory.appendingPathComponent(".codeforge-preview.html")
            do {
                try html.write(to: target, atomically: true, encoding: .utf8)
                temporaryFile = target
                webView.loadFileURL(target, allowingReadAccessTo: directory)
            } catch {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func cleanUp() {
            if let temporaryFile { try? FileManager.default.removeItem(at: temporaryFile) }
            temporaryFile = nil
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let payload = message.body as? [String: Any],
                  let text = payload["text"] as? String else { return }
            let level = payload["level"] as? String ?? "log"
            onConsole(ConsoleMessage(level: level, text: text))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadingChange(false)
            webView.evaluateJavaScript("document.title") { value, _ in
                self.onTitleChange((value as? String) ?? "")
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadingChange(false)
            onConsole(ConsoleMessage(level: "error", text: error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            onLoadingChange(false)
            onConsole(ConsoleMessage(level: "error", text: error.localizedDescription))
        }
    }
}
