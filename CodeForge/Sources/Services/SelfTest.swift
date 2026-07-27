import Foundation
import UIKit

/// Headless checks the app can run at launch, so CI verifies the machinery the
/// preview depends on instead of only checking that the app opens.
///
/// Launch with `--selftest`; results are written to the system log where the
/// smoke-test script greps for them.
enum SelfTest {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--selftest")
    }

    static func run() {
        DispatchQueue.global(qos: .userInitiated).async {
            var failures: [String] = []
            var passed = 0

            func check(_ name: String, _ condition: @autoclosure () -> Bool) {
                if condition() {
                    passed += 1
                    NSLog("SELFTEST ok: %@", name)
                } else {
                    failures.append(name)
                    NSLog("SELFTEST FAIL: %@", name)
                }
            }

            // --- the loopback server ---------------------------------------
            let started = LocalWebServer.shared.start()
            check("server starts", started)
            check("server has a port", LocalWebServer.shared.port != 0)

            guard let base = LocalWebServer.shared.baseURL else {
                NSLog("SELFTEST RESULT fail (server unavailable)")
                return
            }

            // --- bundled runtimes -------------------------------------------
            let runtimeRoot = RuntimeCatalog.shared.rootURL
            check("runtimes folder is bundled", runtimeRoot != nil)
            if let runtimeRoot {
                LocalWebServer.shared.mount(runtimeRoot, at: "runtime")
            }
            for runtime in RuntimeCatalog.shared.all {
                check("runtime available: \(runtime.id)", runtime.isAvailable)
            }

            // --- serving those files over HTTP --------------------------------
            let expected: [(String, Int)] = [
                ("/runtime/pages/python.html", 500),
                ("/runtime/pages/lua.html", 500),
                ("/runtime/pages/sql.html", 500),
                ("/runtime/pyodide/pyodide.js", 5_000),
                ("/runtime/pyodide/pyodide.asm.wasm", 1_000_000),
                ("/runtime/pyodide/python_stdlib.zip", 100_000),
                ("/runtime/fengari/fengari-web.js", 50_000),
                ("/runtime/sqljs/sql-wasm.js", 10_000),
                ("/runtime/sqljs/sql-wasm.wasm", 100_000)
            ]
            for (path, minimumSize) in expected {
                let (status, size) = get(base.appendingPathComponent(String(path.dropFirst())))
                check("GET \(path) [\(status), \(size) bytes]", status == 200 && size >= minimumSize)
            }

            // --- range requests, which media elements depend on -------------------
            var ranged = URLRequest(url: base.appendingPathComponent("runtime/pages/terminal.css"))
            ranged.setValue("bytes=0-9", forHTTPHeaderField: "Range")
            let (rangeStatus, rangeSize) = send(ranged)
            check("range request returns 206 with 10 bytes [\(rangeStatus), \(rangeSize)]",
                  rangeStatus == 206 && rangeSize == 10)

            // --- the server must not serve outside its mounts -------------------
            if let escape = URL(string: base.absoluteString + "/runtime/../../../etc/passwd") {
                let (status, _) = get(escape)
                check("path traversal is refused", status != 200)
            }
            let (unmountedStatus, _) = get(base.appendingPathComponent("nowhere/file.txt"))
            check("unmounted prefix is refused", unmountedStatus == 404)

            // --- the syntax engine ------------------------------------------------
            check("languages registered", LanguageRegistry.shared.all.count > 100)
            let swift = LanguageRegistry.shared.language(forFilename: "main.swift")
            check("swift is detected", swift.id == "swift")
            let tokens = SyntaxScanner(language: swift).tokenize("let x = \"hi\" // note")
            check("scanner produces tokens", tokens.count >= 4)
            check("markdown renders", MarkdownRenderer.html(from: "# Title", theme: Themes.midnight)
                .contains("<h1"))
            check("no duplicate translations: \(Localization.duplicateKeys.joined(separator: ", "))",
                  Localization.duplicateKeys.isEmpty)
            check("japanese lookup works",
                  Localization.japanese["Save"] != nil && Localization.japanese["Run"] != nil)

            // --- the line index, on a document big enough to matter -------------
            //
            // This is the trickiest code in the editor: it is patched in place
            // on every edit, and the gutter, the caret readout and go-to-line
            // all read it. A wrong entry is a wrong line number everywhere.
            let lineCount = 20_000
            let body = (0..<lineCount).map { "line \($0) with some text" }.joined(separator: "\n")
            let storage = CodeTextStorage()
            storage.syntaxHighlightingEnabled = false
            let indexingBegan = Date()
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: body)
            storage.documentDidChangeWholesale()
            let indexed = Date().timeIntervalSince(indexingBegan)

            check("index counts \(lineCount) lines [\(storage.lineCount)]",
                  storage.lineCount == lineCount)
            check("index built in \(String(format: "%.3f", indexed))s", indexed < 2.0)
            check("first line starts at 0", storage.startOfLine(1) == 0)
            check("line lookup round-trips",
                  storage.lineNumber(at: storage.startOfLine(12_345)) == 12_345)

            // An edit in the middle must shift everything after it and nothing
            // before it.
            let anchorBefore = storage.startOfLine(100)
            let insertAt = storage.startOfLine(5_000)
            storage.replaceCharacters(in: NSRange(location: insertAt, length: 0), with: "inserted\n")
            check("edit keeps earlier lines put", storage.startOfLine(100) == anchorBefore)
            check("edit adds one line [\(storage.lineCount)]", storage.lineCount == lineCount + 1)
            check("line after the edit is still found",
                  storage.lineNumber(at: storage.startOfLine(9_000)) == 9_000)

            let removeStart = storage.startOfLine(200)
            let removeEnd = storage.startOfLine(300)
            storage.replaceCharacters(in: NSRange(location: removeStart,
                                                  length: removeEnd - removeStart), with: "")
            check("deleting 100 lines removes 100 entries [\(storage.lineCount)]",
                  storage.lineCount == lineCount + 1 - 100)
            check("deletion keeps the line above put", storage.startOfLine(200) == removeStart)

            // The no-copy NSString view is what every hot path reads now, so it
            // has to track the buffer exactly.
            check("nsString length tracks the buffer [\(storage.nsString.length)]",
                  storage.nsString.length == storage.length)
            check("nsString content matches", storage.nsString.substring(to: 6) == "line 0")

            // The incremental index must agree with a from-scratch scan; that is
            // the property every gutter and caret readout depends on.
            let patched = storage.lineStarts
            storage.documentDidChangeWholesale()
            check("incremental index matches a full rebuild", patched == storage.lineStarts)

            // --- a real text view, driven the way a person drives it ----------
            //
            // The checks above all run against the storage. A build shipped
            // where 2,800 lines was enough to hang the app, because the cost
            // was in the *view*: the caret setter forced glyph layout from
            // inside UIKit's own text processing. So the editor is exercised
            // end to end here — layout, caret moves down the file, scrolling
            // and a full repaint — against a wall-clock budget.
            func makeBody(lines: Int) -> String {
                (0..<lines).map { index in
                    switch index % 4 {
                    case 0: return "    // step \(index): explain what happens next"
                    case 1: return "    let value\(index) = compute(\"text \(index)\", index: \(index))"
                    case 2: return "    if value\(index) > 0 { total += value\(index) }"
                    default: return ""
                    }
                }.joined(separator: "\n")
            }
            let stressLines = 3_000
            let stressBody = makeBody(lines: stressLines)

            // The first run of this measured 79 ms to scroll one screen, which
            // is five frames' worth of budget for one step, and turning
            // non-contiguous layout off changed nothing. So the cost is
            // attributed here instead of guessed at: the same scroll is run
            // against a plain UITextView over the same text (the control), then
            // against ours with the chrome and the highlighting turned off one
            // at a time, and finally on a document four times the size to see
            // whether the per-screen cost grows with the file.
            var results: [String: Double] = [:]
            var painted = false

            /// Scrolls forward a screen at a time and returns milliseconds per step.
            func scrollCost(lines: Int, chrome: Bool, highlighting: Bool,
                            plainTextView: Bool) -> Double {
                let text = lines == stressLines ? stressBody : makeBody(lines: lines)
                let steps = 40
                let view: UITextView

                if plainTextView {
                    let storage = NSTextStorage(string: text)
                    let manager = NSLayoutManager()
                    manager.allowsNonContiguousLayout = true
                    let container = NSTextContainer(size: CGSize(width: 0,
                                                                 height: .greatestFiniteMagnitude))
                    container.widthTracksTextView = true
                    manager.addTextContainer(container)
                    storage.addLayoutManager(manager)
                    view = UITextView(frame: .zero, textContainer: container)
                } else {
                    let storage = CodeTextStorage()
                    storage.language = LanguageRegistry.shared.language(forFilename: "main.swift")
                    storage.syntaxHighlightingEnabled = highlighting
                    let code = CodeTextView(textStorage: storage)
                    code.showLineNumbers = chrome
                    code.showIndentGuides = chrome
                    code.highlightCurrentLine = chrome
                    code.text = text
                    storage.documentDidChangeWholesale()
                    view = code
                }
                view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
                if plainTextView { view.text = text }
                view.layoutIfNeeded()

                let began = Date()
                var offset: CGFloat = 0
                for _ in 0..<steps {
                    offset += view.bounds.height * 0.8
                    view.contentOffset = CGPoint(x: 0, y: offset)
                    (view as? CodeTextView)?.viewportDidChange()
                    view.layoutIfNeeded()
                }
                return Date().timeIntervalSince(began) / Double(steps) * 1000
            }

            DispatchQueue.main.sync {
                let liveStorage = CodeTextStorage()
                liveStorage.language = LanguageRegistry.shared.language(forFilename: "main.swift")
                let view = CodeTextView(textStorage: liveStorage)
                view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)

                var began = Date()
                view.text = stressBody
                liveStorage.documentDidChangeWholesale()
                view.refreshGutter()
                view.layoutIfNeeded()
                results["open (s)"] = Date().timeIntervalSince(began)

                // Typing: the caret moves within one screen.
                began = Date()
                for line in 1...300 {
                    view.selectedRange = NSRange(location: liveStorage.startOfLine(line % 40 + 1),
                                                 length: 0)
                }
                results["caret x300 (s)"] = Date().timeIntervalSince(began)

                // Jumping far, which is go-to-line and find.
                began = Date()
                for line in stride(from: 1, through: stressLines, by: 150) {
                    view.selectedRange = NSRange(location: liveStorage.startOfLine(line), length: 0)
                    view.scrollRangeToVisible(view.selectedRange)
                    view.layoutIfNeeded()
                }
                results["jump x20 (s)"] = Date().timeIntervalSince(began)

                // Forces draw(_:), so the current-line highlight and the indent
                // guides are covered too.
                began = Date()
                let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
                let image = renderer.image { context in view.layer.render(in: context.cgContext) }
                results["paint (s)"] = Date().timeIntervalSince(began)
                painted = image.size.width > 0

                // Attribution. Every figure is milliseconds for one screen.
                results["scroll ms: plain UITextView"] =
                    scrollCost(lines: stressLines, chrome: false, highlighting: false, plainTextView: true)
                results["scroll ms: ours, everything on"] =
                    scrollCost(lines: stressLines, chrome: true, highlighting: true, plainTextView: false)
                results["scroll ms: ours, no chrome"] =
                    scrollCost(lines: stressLines, chrome: false, highlighting: true, plainTextView: false)
                results["scroll ms: ours, no highlighting"] =
                    scrollCost(lines: stressLines, chrome: true, highlighting: false, plainTextView: false)
                results["scroll ms: ours, 12k lines"] =
                    scrollCost(lines: 12_000, chrome: true, highlighting: true, plainTextView: false)
            }

            for (name, value) in results.sorted(by: { $0.key < $1.key }) {
                NSLog("SELFTEST timing: %@ = %.3f", name, value)
            }
            check("the editor paints", painted)
            // Deliberately loose: these guard against a hang or a pathology, not
            // against being a few milliseconds slower than ideal. The timings
            // above are what the optimisation work is steered by.
            check("scrolling stays sane ["
                  + String(format: "%.0fms/screen", results["scroll ms: ours, everything on"] ?? 9999)
                  + "]",
                  (results["scroll ms: ours, everything on"] ?? 9999) < 400)
            check("typing stays sane [" + String(format: "%.2fs", results["caret x300 (s)"] ?? 99) + "]",
                  (results["caret x300 (s)"] ?? 99) < 2.0)
            check("opening stays sane [" + String(format: "%.2fs", results["open (s)"] ?? 99) + "]",
                  (results["open (s)"] ?? 99) < 4.0)

            if failures.isEmpty {
                NSLog("SELFTEST RESULT pass (%d checks)", passed)
            } else {
                NSLog("SELFTEST RESULT fail (%d failed: %@)", failures.count,
                      failures.joined(separator: ", "))
            }
        }
    }

    /// Synchronous GET used only by the self test.
    private static func get(_ url: URL) -> (status: Int, size: Int) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        return send(request)
    }

    private static func send(_ original: URLRequest) -> (status: Int, size: Int) {
        var request = original
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        var status = -1
        var size = 0
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode ?? -1
            size = data?.count ?? 0
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 15)
        return (status, size)
    }
}
