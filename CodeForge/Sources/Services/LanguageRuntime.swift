import Foundation

/// A language runtime that ships inside the app and executes user code
/// on-device.
///
/// iOS forbids generating machine code at runtime (no writable-executable
/// pages without the JIT entitlement), which rules out shipping a compiler for
/// Swift, Go, Rust or C. It does **not** forbid interpreters: an interpreter
/// compiled ahead of time treats the user's program as data, which is how
/// every scripting app on the platform works. These runtimes are WebAssembly
/// builds executed by the system's own web engine, so they need no entitlement
/// and no network — everything is bundled.
struct LanguageRuntime: Identifiable {

    let id: String
    let displayName: String
    /// Page inside `Runtimes/pages` that drives the runtime.
    let page: String
    /// One file that must exist for the runtime to be considered installed.
    let probeFile: String
    let languageIDs: Set<String>
    let notes: String

    var isAvailable: Bool {
        guard let root = RuntimeCatalog.shared.rootURL else { return false }
        return FileManager.default.fileExists(atPath: root.appendingPathComponent(probeFile).path)
    }
}

final class RuntimeCatalog {

    static let shared = RuntimeCatalog()

    /// The bundled `Runtimes` folder, if the build included one.
    let rootURL: URL? = Bundle.main.url(forResource: "Runtimes", withExtension: nil)

    let all: [LanguageRuntime] = [
        LanguageRuntime(
            id: "python",
            displayName: "Python 3 (Pyodide)",
            page: "python.html",
            probeFile: "pyodide/pyodide.js",
            languageIDs: ["python", "starlark", "gdscript"],
            notes: "CPython compiled to WebAssembly. 標準ライブラリ同梱、ネット接続不要。"),

        LanguageRuntime(
            id: "lua",
            displayName: "Lua 5.4 (Fengari)",
            page: "lua.html",
            probeFile: "fengari/fengari-web.js",
            languageIDs: ["lua"],
            notes: "Lua VM in JavaScript."),

        LanguageRuntime(
            id: "sql",
            displayName: "SQLite (sql.js)",
            page: "sql.html",
            probeFile: "sqljs/sql-wasm.js",
            languageIDs: ["sql", "plsql"],
            notes: "SQLite compiled to WebAssembly. 実行結果を表で表示します。")
    ]

    func runtime(for language: LanguageDefinition) -> LanguageRuntime? {
        all.first { $0.languageIDs.contains(language.id) }
    }

    /// Runtimes present in this build — the "what can actually run" list shown
    /// in Help.
    var installed: [LanguageRuntime] { all.filter(\.isAvailable) }
}
