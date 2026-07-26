import Foundation

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
