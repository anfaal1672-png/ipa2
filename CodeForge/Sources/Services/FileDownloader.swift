import Foundation
import UniformTypeIdentifiers

/// Fetches a file from a URL into the workspace.
///
/// Enough to pull down a library, a stylesheet or an image without leaving the
/// app — which on a phone, where the alternative is Safari plus the Files app
/// plus an import, is the difference between doing it and not bothering.
enum FileDownloader {

    enum DownloadError: LocalizedError {
        case notAURL
        case unsupportedScheme(String)
        case badStatus(Int)

        var errorDescription: String? {
            switch self {
            case .notAURL:
                return L("That does not look like a web address.")
            case .unsupportedScheme(let scheme):
                return "\(L("Only http and https can be downloaded.")) (\(scheme))"
            case .badStatus(let code):
                return "\(L("The server refused the request.")) (HTTP \(code))"
            }
        }
    }

    /// Accepts what someone actually pastes: with or without a scheme, with
    /// stray whitespace around it.
    static func normalised(_ text: String) -> Result<URL, DownloadError> {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.notAURL) }

        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              url.host?.isEmpty == false else {
            return .failure(.notAURL)
        }
        guard scheme == "http" || scheme == "https" else {
            return .failure(.unsupportedScheme(scheme))
        }
        return .success(url)
    }

    /// What to call the downloaded file: the name the server gives, else the
    /// last path component, else something derived from the content type. A
    /// download from `https://example.com/` must not land as an empty name.
    static func suggestedName(for response: URLResponse?, url: URL) -> String {
        if let http = response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition"),
           let name = filename(fromContentDisposition: disposition) {
            return name
        }

        let component = url.lastPathComponent
        if !component.isEmpty, component != "/", (component as NSString).pathExtension.isEmpty == false {
            return component
        }

        var base = component.isEmpty || component == "/" ? (url.host ?? "download") : component
        base = base.replacingOccurrences(of: "/", with: "")
        if (base as NSString).pathExtension.isEmpty {
            let ext = response?.mimeType
                .flatMap { UTType(mimeType: $0) }?
                .preferredFilenameExtension ?? "txt"
            base += ".\(ext)"
        }
        return base
    }

    private static func filename(fromContentDisposition header: String) -> String? {
        for part in header.components(separatedBy: ";") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard piece.lowercased().hasPrefix("filename=") else { continue }
            var value = String(piece.dropFirst("filename=".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            // A server that sends a path here must not be able to write outside
            // the folder the user chose.
            value = (value as NSString).lastPathComponent
            if !value.isEmpty, value != ".", value != ".." { return value }
        }
        return nil
    }

    /// Downloads to a scratch file and hands back where it landed. The caller
    /// copies it into the project, so a failed download leaves nothing behind.
    static func download(from text: String,
                         completion: @escaping (Result<URL, Error>) -> Void) {
        let url: URL
        switch normalised(text) {
        case .success(let resolved): url = resolved
        case .failure(let error):
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.downloadTask(with: request) { location, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                DispatchQueue.main.async {
                    completion(.failure(DownloadError.badStatus(http.statusCode)))
                }
                return
            }
            guard let location else {
                DispatchQueue.main.async { completion(.failure(DownloadError.notAURL)) }
                return
            }

            let scratch = FileManager.default.temporaryDirectory
                .appendingPathComponent("codeforge-download", isDirectory: true)
            try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            let destination = scratch.appendingPathComponent(suggestedName(for: response, url: url))
            try? FileManager.default.removeItem(at: destination)
            do {
                // The temporary file is removed as soon as this handler returns.
                try FileManager.default.moveItem(at: location, to: destination)
                DispatchQueue.main.async { completion(.success(destination)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
