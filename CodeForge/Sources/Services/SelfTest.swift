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
            let stressLines = 3_000
            let stressBody = (0..<stressLines).map { index in
                switch index % 4 {
                case 0: return "    // step \(index): explain what happens next"
                case 1: return "    let value\(index) = compute(\"text \(index)\", index: \(index))"
                case 2: return "    if value\(index) > 0 { total += value\(index) }"
                default: return ""
                }
            }.joined(separator: "\n")

            // Each phase is timed separately, and the whole run is repeated with
            // non-contiguous layout off, because which of the two is faster for
            // a document this size is a question about UIKit's behaviour that
            // only a measurement on a device can answer. Every number is logged.
            var results: [String: Double] = [:]
            var painted = false

            DispatchQueue.main.sync {
                for nonContiguous in [true, false] {
                    let label = nonContiguous ? "noncontiguous" : "contiguous"
                    let liveStorage = CodeTextStorage()
                    liveStorage.language = LanguageRegistry.shared.language(forFilename: "main.swift")
                    let view = CodeTextView(textStorage: liveStorage,
                                            nonContiguousLayout: nonContiguous)
                    view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

                    var began = Date()
                    view.text = stressBody
                    liveStorage.documentDidChangeWholesale()
                    view.refreshGutter()
                    view.layoutIfNeeded()
                    results["\(label) open"] = Date().timeIntervalSince(began)

                    // Scrolling the way a finger does: forward, one screen at a
                    // time. This is the number that decides whether the app
                    // feels heavy.
                    began = Date()
                    var offset: CGFloat = 0
                    for _ in 0..<40 {
                        offset += view.bounds.height * 0.8
                        view.contentOffset = CGPoint(x: 0, y: offset)
                        view.viewportDidChange()
                        view.layoutIfNeeded()
                    }
                    results["\(label) scroll"] = Date().timeIntervalSince(began)

                    // Typing: the caret moves within one screen.
                    began = Date()
                    view.contentOffset = .zero
                    for line in 1...300 {
                        view.selectedRange = NSRange(location: liveStorage.startOfLine(line % 40 + 1),
                                                     length: 0)
                    }
                    results["\(label) caret"] = Date().timeIntervalSince(began)

                    // Jumping far, which is go-to-line and find.
                    began = Date()
                    for line in stride(from: 1, through: stressLines, by: 150) {
                        view.selectedRange = NSRange(location: liveStorage.startOfLine(line), length: 0)
                        view.scrollRangeToVisible(view.selectedRange)
                        view.layoutIfNeeded()
                    }
                    results["\(label) jump"] = Date().timeIntervalSince(began)

                    // Forces draw(_:), so the current-line highlight and the
                    // indent guides are covered too.
                    began = Date()
                    let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
                    let image = renderer.image { context in view.layer.render(in: context.cgContext) }
                    results["\(label) paint"] = Date().timeIntervalSince(began)
                    painted = painted || image.size.width > 0
                }
            }

            for (name, seconds) in results.sorted(by: { $0.key < $1.key }) {
                NSLog("SELFTEST timing: %@ %.3fs (%d lines)", name, seconds, stressLines)
            }
            check("the editor paints", painted)
            // The shipped configuration has to keep ordinary scrolling and
            // typing cheap. Far jumps are allowed to cost more: they make TextKit
            // lay out everything in between whatever we do.
            check("scrolling \(stressLines) lines took "
                  + String(format: "%.2f", results["noncontiguous scroll"] ?? 99) + "s",
                  (results["noncontiguous scroll"] ?? 99) < 3.0)
            check("typing over \(stressLines) lines took "
                  + String(format: "%.2f", results["noncontiguous caret"] ?? 99) + "s",
                  (results["noncontiguous caret"] ?? 99) < 2.0)
            check("opening \(stressLines) lines took "
                  + String(format: "%.2f", results["noncontiguous open"] ?? 99) + "s",
                  (results["noncontiguous open"] ?? 99) < 3.0)

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
