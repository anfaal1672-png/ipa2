import SwiftUI
import UIKit
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

    /// True when previewing means running code rather than rendering markup.
    var isExecutable: Bool {
        switch self {
        case .runtime, .javascript: return true
        default: return false
        }
    }
}

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let level: String
    let text: String
    /// How many times this exact line has been reported. A loop that throws on
    /// every iteration should read as one entry with a tally, not as a thousand
    /// rows burying everything else.
    var count: Int = 1

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

/// The console's contents, with repeats collapsed.
///
/// A separate type rather than a handful of `@State` properties so the
/// collapsing rule is covered by the self test — the interesting behaviour is
/// all in `record`, and none of it needs a view to exercise.
struct ConsoleLog {

    private(set) var messages: [ConsoleMessage] = []
    /// level + text → where that line already sits in `messages`.
    private var index: [String: Int] = [:]
    private(set) var isFull = false

    /// A page in a bad loop can report faster than anything can read; past this
    /// many *distinct* lines the log stops growing. Repeats still count.
    static let cap = 2_000

    var isEmpty: Bool { messages.isEmpty }
    var errorCount: Int { messages.filter { $0.level == "error" }.count }

    mutating func record(_ message: ConsoleMessage) {
        let key = message.level + "\u{0}" + message.text
        if let existing = index[key] {
            // Counted in place: the entry keeps its original position, so the
            // order of the log still means something.
            messages[existing].count += 1
            return
        }
        guard messages.count < Self.cap else {
            if !isFull {
                isFull = true
                messages.append(ConsoleMessage(
                    level: "warn",
                    text: L("Too many different messages — the rest are not shown.")))
            }
            return
        }
        index[key] = messages.count
        messages.append(message)
    }

    mutating func clear() {
        messages.removeAll()
        index.removeAll()
        isFull = false
    }

    /// One line per entry, tagged with its level so an error is still
    /// recognisable once pasted somewhere else. A repeated line appears once —
    /// the tally is on screen, and pasting the same stack trace a thousand
    /// times helps nobody.
    var copyText: String {
        messages.map { message in
            message.level == "log" ? message.text : "[\(message.level)] \(message.text)"
        }.joined(separator: "\n")
    }
}

/// Live preview: renders the file, and for HTML, JavaScript, Python, Lua and
/// SQL actually *runs* it.
struct PreviewView: View {

    @ObservedObject var document: CodeDocument
    let theme: EditorTheme
    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss

    @State private var log = ConsoleLog()
    @State private var showConsole = false
    @State private var reloadToken = 0
    @State private var autoRefresh = true
    @State private var isLoading = false
    @State private var pageTitle = ""
    @State private var request: PreviewRequest?

    /// Full screen hands the whole display to the page: no navigation bar, no
    /// status bar, no runtime strip. The only chrome left is a small floating
    /// bar that dims itself once the page has settled, and comes back on a tap.
    @State private var isFullScreen = false
    @State private var controlsAreDimmed = false
    @State private var showFullScreenHint = false
    @State private var dimTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?

    @State private var didCopy = false
    @State private var copyResetTask: Task<Void, Never>?

    private var kind: PreviewKind { PreviewKind.kind(for: document.language) }
    private var errorCount: Int { log.errorCount }

    private var runtimeName: String? {
        guard case .runtime(let id) = kind else { return nil }
        return RuntimeCatalog.shared.all.first { $0.id == id }?.displayName
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    if kind == .unsupported {
                        unsupportedState
                    } else if let request {
                        WebPreview(request: request,
                                   reloadToken: reloadToken,
                                   onConsole: { message in
                                       log.record(message)
                                       // A page that renders wrong because a
                                       // script died is worse than useless if the
                                       // reason stays hidden behind a button.
                                       // In full screen the floating bar shows a
                                       // red dot instead, so the page is not
                                       // shoved aside by a panel.
                                       if message.level == "error" && !showConsole && !isFullScreen {
                                           showConsole = true
                                       }
                                   },
                                   onLoadingChange: { isLoading = $0 },
                                   onTitleChange: { pageTitle = $0 },
                                   onInteraction: { wakeControls() })
                            .background(Color(theme.background))
                    } else {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if let runtimeName, kind != .unsupported, !isFullScreen {
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

                if isFullScreen {
                    floatingControls
                        .padding(.top, 10)
                        .padding(.trailing, 14)
                }
            }
            .ignoresSafeArea(edges: isFullScreen ? .all : [])
            .navigationTitle(pageTitle.isEmpty ? document.name : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isFullScreen ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Done")) { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if isLoading { ProgressView().controlSize(.small) }

                    Button {
                        log.clear()
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
                            } else if !log.isEmpty {
                                Circle().fill(Color(theme.accent)).frame(width: 7, height: 7).offset(x: 5, y: -3)
                            }
                        }
                    }
                    .accessibilityLabel(L("Console"))

                    Button { enterFullScreen() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityLabel(L("Full screen"))

                    Menu {
                        Toggle(L("Reload when the file changes"), isOn: $autoRefresh)
                        Button { enterFullScreen() } label: {
                            Label(L("Full screen"),
                                  systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        Button {
                            log.clear()
                        } label: { Label(L("Clear console"), systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showFullScreenHint {
                    Text(L("Tap the screen to show the buttons again"))
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
            .statusBarHidden(isFullScreen)
            .onAppear { rebuild() }
            .onDisappear {
                dimTask?.cancel()
                hintTask?.cancel()
                copyResetTask?.cancel()
                PreviewWorkspace.shared.cleanUp()
            }
            .onChange(of: document.revision) { _ in
                guard autoRefresh else { return }
                rebuild()
                reloadToken += 1
            }
        }
    }

    // MARK: - Full screen

    private var floatingControls: some View {
        HStack(spacing: 16) {
            Button {
                log.clear()
                rebuild()
                reloadToken += 1
                wakeControls()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel(L("Reload"))

            Button {
                showConsole.toggle()
                wakeControls()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "terminal")
                    if errorCount > 0 {
                        Circle().fill(Color.red).frame(width: 7, height: 7).offset(x: 5, y: -3)
                    }
                }
            }
            .accessibilityLabel(L("Console"))

            Button { exitFullScreen() } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .accessibilityLabel(L("Exit full screen"))
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(controlsAreDimmed ? 0.28 : 1)
        .animation(.easeInOut(duration: 0.25), value: controlsAreDimmed)
    }

    private func enterFullScreen() {
        showConsole = false
        withAnimation(.easeInOut(duration: 0.2)) { isFullScreen = true }
        withAnimation { showFullScreenHint = true }
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { showFullScreenHint = false }
        }
        wakeControls()
    }

    private func exitFullScreen() {
        dimTask?.cancel()
        controlsAreDimmed = false
        withAnimation(.easeInOut(duration: 0.2)) { isFullScreen = false }
    }

    /// Brings the floating bar back to full strength and restarts the fade.
    /// It only ever dims — never disappears — so there is always something to
    /// tap to get out.
    private func wakeControls() {
        guard isFullScreen else { return }
        dimTask?.cancel()
        controlsAreDimmed = false
        dimTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            controlsAreDimmed = true
        }
    }

    private func rebuild() {
        request = PreviewWorkspace.shared.prepare(document: document, kind: kind, theme: theme)
    }

    // MARK: - Console


    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        withAnimation { didCopy = true }
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { didCopy = false }
        }
    }

    private var consolePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("Console")).font(.caption.weight(.semibold))
                Text("\(log.messages.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                if didCopy {
                    Label(L("Copied"), systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                Button { copy(log.copyText) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .font(.caption)
                .disabled(log.isEmpty)
                .accessibilityLabel(L("Copy all"))

                Button(L("Clear console")) { log.clear() }.font(.caption)
                Button { showConsole = false } label: { Image(systemName: "chevron.down") }
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if log.isEmpty {
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
                            ForEach(log.messages) { message in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: message.icon)
                                        .font(.system(size: 9))
                                        .foregroundColor(message.color)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(message.text)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(message.color)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if message.count > 1 {
                                            Text("×\(message.count)")
                                                .font(.system(size: 10, weight: .semibold,
                                                              design: .rounded))
                                                .monospacedDigit()
                                                .foregroundColor(message.color)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(message.color.opacity(0.15),
                                                            in: Capsule())
                                                // Not selectable, so a drag over
                                                // the log copies the message and
                                                // not the tally beside it.
                                                .textSelection(.disabled)
                                                .accessibilityLabel(
                                                    "\(L("Repeated")) \(message.count)")
                                        }
                                    }
                                }
                                .id(message.id)
                                // Long press for one line; the button in the
                                // header takes the lot. Dragging across lines
                                // selects freely thanks to textSelection below.
                                .contextMenu {
                                    Button {
                                        copy(message.text)
                                    } label: { Label(L("Copy"), systemImage: "doc.on.doc") }
                                    Button {
                                        copy(log.copyText)
                                    } label: { Label(L("Copy all"), systemImage: "doc.on.doc.fill") }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                        // On the stack rather than each line, so a drag can
                        // select across several messages at once.
                        .textSelection(.enabled)
                    }
                    .onChange(of: log.messages.count) { _ in
                        if let last = log.messages.last {
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

        // Preferably the file's own folder, so its relative paths resolve; a
        // scratch folder when there is no file yet or the folder is read-only.
        var directory = document.url?.deletingLastPathComponent() ?? scratchDirectory
        if !FileManager.default.isWritableFile(atPath: directory.path) {
            directory = scratchDirectory
        }
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
            let fileExtension = document.url?.pathExtension ?? ""
            let ext = fileExtension.isEmpty
                ? (document.language.extensions.first ?? "txt")
                : fileExtension
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

    /// Removes scratch files a previous run left behind — the app being killed
    /// mid-preview is the normal way an iOS app exits.
    static func sweepStaleFiles(in root: URL) {
        let manager = FileManager.default
        guard let walker = manager.enumerator(at: root,
                                              includingPropertiesForKeys: nil,
                                              options: [.skipsPackageDescendants]) else { return }
        for case let url as URL in walker where url.lastPathComponent.hasPrefix(".codeforge-") {
            try? manager.removeItem(at: url)
        }
    }
}

// MARK: - WebView

private struct WebPreview: UIViewRepresentable {

    let request: PreviewRequest
    let reloadToken: Int
    let onConsole: (ConsoleMessage) -> Void
    let onLoadingChange: (Bool) -> Void
    let onTitleChange: (String) -> Void
    /// Any touch on the page. Used to bring the full-screen controls back.
    var onInteraction: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onConsole: onConsole, onLoadingChange: onLoadingChange,
                    onTitleChange: onTitleChange, onInteraction: onInteraction)
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

        // Observes touches without consuming them, so the page still gets every
        // tap while the full-screen controls learn that the user is there.
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleInteraction))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = context.coordinator
        webView.addGestureRecognizer(tap)

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

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate,
                             UIGestureRecognizerDelegate {

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
          // Capture phase, because a <script>/<link>/<img> that fails to load
          // fires on the element, not on window — and a silently missing CDN
          // script is exactly the kind of failure that leaves a page
          // half-built with no error in sight.
          window.addEventListener('error', function (event) {
            var target = event.target;
            if (!target || target === window || !target.tagName) { return; }
            var url = target.src || target.href;
            if (!url) { return; }
            send('error', ['読み込めませんでした: <' + target.tagName.toLowerCase() + '> ' + url]);
          }, true);
          window.addEventListener('unhandledrejection', function (event) {
            send('error', ['Unhandled promise rejection: ' + stringify(event.reason)]);
          });
        })();
        """

        private let onConsole: (ConsoleMessage) -> Void
        private let onLoadingChange: (Bool) -> Void
        private let onTitleChange: (String) -> Void
        private let onInteraction: () -> Void
        var lastToken = -1

        init(onConsole: @escaping (ConsoleMessage) -> Void,
             onLoadingChange: @escaping (Bool) -> Void,
             onTitleChange: @escaping (String) -> Void,
             onInteraction: @escaping () -> Void) {
            self.onConsole = onConsole
            self.onLoadingChange = onLoadingChange
            self.onTitleChange = onTitleChange
            self.onInteraction = onInteraction
        }

        @objc func handleInteraction() { onInteraction() }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
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

        // MARK: Hardware the page asks for
        //
        // A file input's picker is WebKit's own and needs nothing from us, but
        // a page that reaches for the camera through JavaScript does: with no
        // answer to these, `getUserMedia()` and `DeviceMotionEvent` fail
        // silently, which looks like broken code rather than a missing
        // permission. `.prompt` hands the decision to the user — WebKit asks,
        // and iOS asks again the first time the hardware is touched.

        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.prompt)
        }

        func webView(_ webView: WKWebView,
                     requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.prompt)
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
