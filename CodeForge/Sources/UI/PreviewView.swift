import SwiftUI
import WebKit

/// What the preview does with a given file.
enum PreviewKind: Equatable {
    case html            // rendered in place, scripts and all
    case markdown        // converted to HTML, code blocks coloured
    case svg
    case css             // applied to a sample page
    case javascript      // executed, console output captured
    case json            // validated and pretty printed
    case runtime(String) // executed by a bundled language runtime (its id)
    case unsupported

    static func kind(for language: LanguageDefinition) -> PreviewKind {
        switch language.id {
        case "html", "xml", "vue", "svelte", "erb", "jinja", "blade": return .html
        case "markdown": return .markdown
        case "css", "scss", "less", "stylus": return .css
        case "javascript", "jsx": return .javascript
        case "json", "jsonc": return .json
        default:
            if language.extensions.contains("svg") { return .svg }
            if let runtime = RuntimeCatalog.shared.runtime(for: language), runtime.isAvailable {
                return .runtime(runtime.id)
            }
            return .unsupported
        }
    }
}

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let level: String
    let text: String

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

/// Live preview: renders the file, and for HTML, JavaScript, Python, Lua and
/// SQL actually *runs* it.
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
    @State private var request: PreviewRequest?

    private var kind: PreviewKind { PreviewKind.kind(for: document.language) }
    private var errorCount: Int { messages.filter { $0.level == "error" }.count }

    private var runtimeName: String? {
        guard case .runtime(let id) = kind else { return nil }
        return RuntimeCatalog.shared.all.first { $0.id == id }?.displayName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if kind == .unsupported {
                    unsupportedState
                } else if let request {
                    WebPreview(request: request,
                               reloadToken: reloadToken,
                               onConsole: { messages.append($0) },
                               onLoadingChange: { isLoading = $0 },
                               onTitleChange: { pageTitle = $0 })
                        .background(Color(theme.background))
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let runtimeName, kind != .unsupported {
                    Text(runtimeName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(theme.gutterForeground))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Color(theme.gutterBackground))
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
                        rebuild()
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
            .onAppear { rebuild() }
            .onDisappear { PreviewWorkspace.shared.cleanUp() }
            .onChange(of: document.revision) { _ in
                guard autoRefresh else { return }
                rebuild()
                reloadToken += 1
            }
        }
    }

    private func rebuild() {
        request = PreviewWorkspace.shared.prepare(document: document, kind: kind, theme: theme)
    }

    // MARK: - Console

    private var consolePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("Console")).font(.caption.weight(.semibold))
                Text("\(messages.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Button(L("Clear console")) { messages.removeAll() }.font(.caption)
                Button { showConsole = false } label: { Image(systemName: "chevron.down") }
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
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
                Text(L("This file type cannot be run on the device"))
                    .font(.headline)
                Text(L("iOS does not let an app generate machine code at runtime, so a compiler for this language cannot ship inside the app. Interpreters can, and these are bundled:"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(RuntimeCatalog.shared.all) { runtime in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: runtime.isAvailable ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundColor(runtime.isAvailable ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(runtime.displayName).font(.callout.weight(.medium))
                                Text(runtime.notes).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HTML · CSS · JavaScript · Markdown · JSON · SVG")
                                .font(.callout.weight(.medium))
                            Text(L("Rendered and executed by the system web engine."))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(theme.currentLine)))
                .padding(.horizontal, 20)

                Spacer(minLength: 30)
            }
        }
    }
}

// MARK: - Building what gets loaded

struct PreviewRequest: Equatable {
    /// Loaded over the loopback server when it is running.
    var url: URL?
    /// Used when the server could not start.
    var fallbackHTML: String?
    var readAccessDirectory: URL?
}

/// Prepares the files a preview loads, and cleans them up afterwards.
///
/// Pages are written *beside the original file* so relative paths behave as
/// they do on a desktop, and served over the loopback server so `fetch`,
/// modules and WebAssembly all work — none of which is possible from `file://`.
final class PreviewWorkspace {

    static let shared = PreviewWorkspace()

    private var temporaryFiles: [URL] = []

    private var scratchDirectory: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codeforge-preview")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func prepare(document: CodeDocument, kind: PreviewKind, theme: EditorTheme) -> PreviewRequest {
        cleanUp()

        let directory = document.url?.deletingLastPathComponent() ?? scratchDirectory
        let serverIsUp = LocalWebServer.shared.start()
        if serverIsUp {
            LocalWebServer.shared.mount(directory, at: "doc")
            if let runtimes = RuntimeCatalog.shared.rootURL {
                LocalWebServer.shared.mount(runtimes, at: "runtime")
            }
        }

        switch kind {
        case .runtime(let runtimeID):
            guard let runtime = RuntimeCatalog.shared.all.first(where: { $0.id == runtimeID }),
                  serverIsUp, let base = LocalWebServer.shared.baseURL else {
                return PreviewRequest(fallbackHTML: PreviewPage.message(
                    title: L("The runtime could not start"), theme: theme))
            }
            let ext = document.url?.pathExtension.isEmpty == false
                ? document.url!.pathExtension
                : (document.language.extensions.first ?? "txt")
            let sourceFile = directory.appendingPathComponent(".codeforge-run.\(ext)")
            try? document.text.write(to: sourceFile, atomically: true, encoding: .utf8)
            temporaryFiles.append(sourceFile)

            var components = URLComponents(url: base.appendingPathComponent("runtime/pages/\(runtime.page)"),
                                           resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "src", value: "/doc/\(sourceFile.lastPathComponent)")]
            return PreviewRequest(url: components?.url, readAccessDirectory: directory)

        default:
            let html = PreviewPage.html(for: document, kind: kind, theme: theme)
            guard serverIsUp, let base = LocalWebServer.shared.baseURL else {
                return PreviewRequest(fallbackHTML: html, readAccessDirectory: directory)
            }
            let pageFile = directory.appendingPathComponent(".codeforge-preview.html")
            do {
                try html.write(to: pageFile, atomically: true, encoding: .utf8)
                temporaryFiles.append(pageFile)
                return PreviewRequest(url: base.appendingPathComponent("doc/\(pageFile.lastPathComponent)"),
                                      readAccessDirectory: directory)
            } catch {
                return PreviewRequest(fallbackHTML: html, readAccessDirectory: directory)
            }
        }
    }

    func cleanUp() {
        for file in temporaryFiles {
            try? FileManager.default.removeItem(at: file)
        }
        temporaryFiles.removeAll()
    }
}

// MARK: - WebView

private struct WebPreview: UIViewRepresentable {

    let request: PreviewRequest
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
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive
        context.coordinator.load(request, into: webView)
        context.coordinator.lastToken = reloadToken
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastToken != reloadToken else { return }
        context.coordinator.lastToken = reloadToken
        context.coordinator.load(request, into: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "codeforge")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

        /// Mirrors console output and uncaught errors back into the app, which
        /// is what makes this a developer preview rather than a viewer.
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

        init(onConsole: @escaping (ConsoleMessage) -> Void,
             onLoadingChange: @escaping (Bool) -> Void,
             onTitleChange: @escaping (String) -> Void) {
            self.onConsole = onConsole
            self.onLoadingChange = onLoadingChange
            self.onTitleChange = onTitleChange
        }

        func load(_ request: PreviewRequest, into webView: WKWebView) {
            onLoadingChange(true)
            if let url = request.url {
                webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
            } else if let html = request.fallbackHTML {
                webView.loadHTMLString(html, baseURL: request.readAccessDirectory)
            }
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let payload = message.body as? [String: Any],
                  let text = payload["text"] as? String else { return }
            onConsole(ConsoleMessage(level: payload["level"] as? String ?? "log", text: text))
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

        // MARK: JavaScript dialogs
        //
        // Without these, `alert()`, `confirm()` and `prompt()` silently do
        // nothing — and `input()` in Python is built on prompt().

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let presenter = Self.topViewController() else { completionHandler(); return }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("OK"), style: .default) { _ in completionHandler() })
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            guard let presenter = Self.topViewController() else { completionHandler(false); return }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("Cancel"), style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: L("OK"), style: .default) { _ in completionHandler(true) })
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            guard let presenter = Self.topViewController() else { completionHandler(nil); return }
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: L("Cancel"), style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: L("OK"), style: .default) { _ in
                completionHandler(alert.textFields?.first?.text ?? "")
            })
            presenter.present(alert, animated: true)
        }

        private static func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            while let presented = controller?.presentedViewController {
                controller = presented
            }
            return controller
        }
    }
}
