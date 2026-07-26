import Foundation
import Network

/// A loopback-only static HTTP server.
///
/// Why an app needs its own web server: `WKWebView` loaded from `file://`
/// refuses `fetch()`, XHR and ES module imports against neighbouring files, and
/// every WebAssembly runtime worth having (Pyodide, sql.js …) loads its `.wasm`
/// payload that way. Serving over `http://127.0.0.1` gives the page a real
/// origin, so those all work — and relative paths in the user's own HTML behave
/// exactly like they would on a desktop.
///
/// Loopback only: the listener is bound to 127.0.0.1, so nothing outside the
/// device can reach it, and iOS does not consider it local-network access.
final class LocalWebServer {

    static let shared = LocalWebServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "codeforge.webserver")
    private(set) var port: UInt16 = 0

    /// Directories exposed under a URL prefix, e.g. "/runtime" → bundled
    /// runtimes, "/doc" → the folder of the file being previewed.
    private var roots: [String: URL] = [:]
    private let rootsLock = NSLock()

    var isRunning: Bool { listener != nil && port != 0 }

    var baseURL: URL? {
        guard isRunning else { return nil }
        return URL(string: "http://127.0.0.1:\(port)")
    }

    // MARK: - Lifecycle

    @discardableResult
    func start() -> Bool {
        guard listener == nil else { return true }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: .any)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .ready = state, let assigned = listener.port?.rawValue {
                    self?.port = assigned
                }
            }
            listener.start(queue: queue)
            self.listener = listener

            // The port is assigned asynchronously; previewing right after
            // launch would otherwise race with the listener becoming ready.
            let deadline = Date().addingTimeInterval(2)
            while port == 0, Date() < deadline {
                if let assigned = listener.port?.rawValue, assigned != 0 {
                    port = assigned
                    break
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
            return port != 0
        } catch {
            return false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = 0
    }

    func mount(_ directory: URL, at prefix: String) {
        rootsLock.lock()
        roots[prefix] = directory.standardizedFileURL
        rootsLock.unlock()
    }

    func unmount(_ prefix: String) {
        rootsLock.lock()
        roots.removeValue(forKey: prefix)
        rootsLock.unlock()
    }

    private func directory(for prefix: String) -> URL? {
        rootsLock.lock()
        defer { rootsLock.unlock() }
        return roots[prefix]
    }

    // MARK: - Connection handling

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var accumulated = buffer
            if let data { accumulated.append(data) }

            if error != nil || (isComplete && accumulated.isEmpty) {
                connection.cancel()
                return
            }

            // Headers end at the first blank line; this server has no request
            // bodies to worry about.
            guard let headerEnd = accumulated.range(of: Data("\r\n\r\n".utf8)) else {
                if accumulated.count > 64 * 1024 {
                    connection.cancel()
                } else {
                    self.receiveRequest(on: connection, buffer: accumulated)
                }
                return
            }

            let head = String(decoding: accumulated[..<headerEnd.lowerBound], as: UTF8.self)
            self.respond(to: head, on: connection)
        }
    }

    private func respond(to head: String, on connection: NWConnection) {
        let requestLine = head.split(separator: "\r\n", maxSplits: 1,
                                     omittingEmptySubsequences: false).first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            send(status: "400 Bad Request", body: Data(), type: "text/plain", on: connection)
            return
        }
        let method = String(parts[0])
        guard method == "GET" || method == "HEAD" else {
            send(status: "405 Method Not Allowed", body: Data(), type: "text/plain", on: connection)
            return
        }

        var path = String(parts[1])
        if let queryStart = path.firstIndex(of: "?") { path = String(path[..<queryStart]) }
        path = path.removingPercentEncoding ?? path

        guard let fileURL = resolve(path: path) else {
            send(status: "404 Not Found",
                 body: Data("Not found: \(path)".utf8), type: "text/plain", on: connection)
            return
        }

        do {
            let data = method == "HEAD" ? Data() : try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let length = method == "HEAD"
                ? (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
                : data.count
            send(status: "200 OK", body: data, type: Self.contentType(for: fileURL),
                 contentLength: length ?? data.count, on: connection)
        } catch {
            send(status: "404 Not Found", body: Data("Unreadable".utf8),
                 type: "text/plain", on: connection)
        }
    }

    /// Maps a URL path onto a mounted directory, refusing anything that tries
    /// to escape it.
    private func resolve(path: String) -> URL? {
        var components = path.split(separator: "/").map(String.init)
        guard let prefix = components.first else { return nil }
        components.removeFirst()
        guard let root = directory(for: prefix) else { return nil }

        var target = root
        for component in components {
            guard component != "..", component != "." else { return nil }
            target.appendPathComponent(component)
        }
        target = target.standardizedFileURL
        guard target.path == root.path || target.path.hasPrefix(root.path + "/") else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) else {
            return nil
        }
        if isDirectory.boolValue {
            let index = target.appendingPathComponent("index.html")
            return FileManager.default.fileExists(atPath: index.path) ? index : nil
        }
        return target
    }

    private func send(status: String, body: Data, type: String,
                      contentLength: Int? = nil, on connection: NWConnection) {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(type)\r\n"
        header += "Content-Length: \(contentLength ?? body.count)\r\n"
        header += "Cache-Control: no-store\r\n"
        // Deliberately *not* sending COOP/COEP. Cross-origin isolation would
        // unlock SharedArrayBuffer, but `require-corp` also blocks every
        // third-party script, stylesheet and font that does not opt in — which
        // is most CDNs — and a page that works on CodePen would half-load here.
        // The bundled runtimes do not need it.
        header += "Connection: close\r\n\r\n"

        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json", "map": return "application/json; charset=utf-8"
        case "wasm": return "application/wasm"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "zip", "whl": return "application/zip"
        case "data", "bin": return "application/octet-stream"
        case "txt", "text": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
