import Foundation
import SwiftUI

/// Owns the project tree, the open tabs and all file-system mutations.
///
/// Deliberately not actor-isolated: every caller is a SwiftUI view body or a
/// UIKit delegate callback, both of which already run on the main thread, and
/// isolation would only force `await` into computed view properties.
final class WorkspaceStore: ObservableObject {

    @Published private(set) var root: FileItem
    @Published var openDocuments: [CodeDocument] = []
    @Published var activeDocumentID: UUID? {
        didSet {
            // Tabs restored from the last session hold only their path until
            // they are looked at.
            openDocuments.first { $0.id == activeDocumentID }?.ensureLoaded()
        }
    }
    @Published var expandedFolders: Set<String> = []
    @Published var errorMessage: String?
    @Published var treeVersion: Int = 0

    let documentsURL: URL

    /// Set by the editor screen. Anything that reads `document.text` has to
    /// pull the live buffer out of the text view first, since the editor only
    /// mirrors its text on a debounce.
    var flushEditor: (() -> Void)?

    init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        documentsURL = docs
        root = FileItem(url: docs, isDirectory: true)
        seedSamplesIfNeeded()
        PreviewWorkspace.sweepStaleFiles(in: docs)
        root.loadChildren(force: true)
        expandedFolders.insert(docs.path)
        restoreSession()
    }

    var activeDocument: CodeDocument? {
        openDocuments.first { $0.id == activeDocumentID }
    }

    // MARK: - Tabs

    func open(_ item: FileItem) {
        guard !item.isDirectory else { return }
        open(url: item.url)
    }

    func open(url: URL) {
        if let existing = openDocuments.first(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) {
            activeDocumentID = existing.id
            return
        }
        do {
            let document = try CodeDocument.load(from: url)
            openDocuments.append(document)
            activeDocumentID = document.id
            persistSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func newUntitledDocument() {
        let document = CodeDocument(url: nil, text: "")
        openDocuments.append(document)
        activeDocumentID = document.id
    }

    /// Writes a document out, giving an untitled one a file first.
    ///
    /// `save()` returns early when there is no URL, so closing a tab that had
    /// never been saved silently threw away everything typed into it — the tab
    /// simply disappeared. An untitled buffer with something in it now becomes
    /// Untitled.txt in Documents instead.
    private func persist(_ document: CodeDocument) {
        guard document.isDirty else { return }
        do {
            if document.url == nil {
                guard !document.text.isEmpty else { return }
                let url = uniqueURL(in: documentsURL, base: "Untitled", ext: "txt")
                try document.save(to: url)
                refreshTree()
            } else {
                try document.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func close(_ document: CodeDocument) {
        flushEditor?()
        persist(document)
        openDocuments.removeAll { $0.id == document.id }
        if activeDocumentID == document.id {
            activeDocumentID = openDocuments.last?.id
        }
        persistSession()
    }

    func closeAll() {
        flushEditor?()
        openDocuments.forEach { persist($0) }
        openDocuments.removeAll()
        activeDocumentID = nil
        persistSession()
    }

    func saveActiveDocument() {
        flushEditor?()
        guard let document = activeDocument else { return }
        do {
            if document.url == nil {
                let url = uniqueURL(in: documentsURL, base: "Untitled", ext: "txt")
                try document.save(to: url)
                refreshTree()
            } else {
                try document.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAll() {
        flushEditor?()
        openDocuments.forEach { persist($0) }
    }

    // MARK: - File operations

    func createFile(named name: String, in folder: FileItem, contents: String = "") {
        let target = folder.url.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            errorMessage = "「\(name)」\(L("already exists."))"
            return
        }
        do {
            try contents.write(to: target, atomically: true, encoding: .utf8)
            refreshTree()
            expandedFolders.insert(folder.url.path)
            open(url: target)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createFolder(named name: String, in folder: FileItem) {
        let target = folder.url.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            expandedFolders.insert(folder.url.path)
            refreshTree()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ item: FileItem, to newName: String) {
        let target = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: item.url, to: target)
            for document in openDocuments where document.url?.standardizedFileURL == item.url {
                document.url = target
            }
            refreshTree()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func duplicate(_ item: FileItem) {
        let ext = item.url.pathExtension
        let base = item.url.deletingPathExtension().lastPathComponent + " copy"
        let target = uniqueURL(in: item.url.deletingLastPathComponent(), base: base, ext: ext)
        do {
            try FileManager.default.copyItem(at: item.url, to: target)
            refreshTree()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: FileItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            openDocuments.removeAll { document in
                guard let url = document.url else { return false }
                return url.path == item.url.path || url.path.hasPrefix(item.url.path + "/")
            }
            if activeDocumentID != nil, activeDocument == nil {
                activeDocumentID = openDocuments.last?.id
            }
            refreshTree()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Copies files into the workspace, returning where they landed.
    @discardableResult
    func importFiles(from urls: [URL], into folder: URL? = nil) -> [URL] {
        var imported: [URL] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let destination = uniqueURL(in: folder ?? documentsURL,
                                        base: url.deletingPathExtension().lastPathComponent,
                                        ext: url.pathExtension)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                imported.append(destination)
            } catch {
                // Fall back to reading the bytes: some providers hand over a
                // URL that cannot be copied but can be read.
                if let data = try? Data(contentsOf: url) {
                    do {
                        try data.write(to: destination, options: .atomic)
                        imported.append(destination)
                    } catch {
                        errorMessage = "\(url.lastPathComponent): \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "\(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }
        refreshTree()
        return imported
    }

    /// A file handed to the app from elsewhere (Share sheet, "Open in…",
    /// AirDrop). Anything living outside the workspace is copied in first, so
    /// edits are not written into another app's sandbox — or lost with it.
    func openExternal(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        if url.standardizedFileURL.path.hasPrefix(documentsURL.standardizedFileURL.path) {
            open(url: url)
            return
        }
        if let copied = importFiles(from: [url]).first {
            open(url: copied)
        } else {
            open(url: url)
        }
    }

    func uniqueURL(in folder: URL, base: String, ext: String) -> URL {
        var candidate = ext.isEmpty ? folder.appendingPathComponent(base)
                                    : folder.appendingPathComponent(base).appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = "\(base) \(counter)"
            candidate = ext.isEmpty ? folder.appendingPathComponent(name)
                                    : folder.appendingPathComponent(name).appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }

    func refreshTree() {
        refresh(item: root)
        treeVersion &+= 1
        objectWillChange.send()
    }

    private func refresh(item: FileItem) {
        let previousChildren = item.children
        item.invalidate()
        let children = item.loadChildren(force: true)
        for child in children where child.isDirectory {
            if expandedFolders.contains(child.url.path)
                || previousChildren?.contains(where: { $0.id == child.id && $0.children != nil }) == true {
                refresh(item: child)
            }
        }
    }

    func folder(for item: FileItem?) -> FileItem {
        guard let item else { return root }
        return item.isDirectory ? item : (findItem(at: item.url.deletingLastPathComponent()) ?? root)
    }

    func findItem(at url: URL) -> FileItem? {
        func search(_ item: FileItem) -> FileItem? {
            if item.url.standardizedFileURL == url.standardizedFileURL { return item }
            guard item.isDirectory else { return nil }
            for child in item.loadChildren() {
                if let found = search(child) { return found }
            }
            return nil
        }
        return search(root)
    }

    // MARK: - Search across the project

    struct SearchHit: Identifiable {
        let id = UUID()
        let url: URL
        let lineNumber: Int
        let line: String
        let range: NSRange
    }

    func search(_ query: String, caseSensitive: Bool, useRegex: Bool, limit: Int = 500) -> [SearchHit] {
        guard !query.isEmpty else { return [] }
        var hits: [SearchHit] = []
        let regex: NSRegularExpression?
        if useRegex {
            regex = try? NSRegularExpression(pattern: query, options: caseSensitive ? [] : [.caseInsensitive])
            if regex == nil { return [] }
        } else {
            regex = nil
        }

        let enumerator = FileManager.default.enumerator(at: documentsURL,
                                                        includingPropertiesForKeys: [.isRegularFileKey],
                                                        options: [.skipsHiddenFiles])
        while let url = enumerator?.nextObject() as? URL {
            guard hits.count < limit else { break }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize), size < 4_000_000 else { continue }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }

            var lineNumber = 0
            contents.enumerateLines { line, stop in
                lineNumber += 1
                if let regex {
                    let ns = line as NSString
                    if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                        hits.append(SearchHit(url: url, lineNumber: lineNumber, line: line, range: match.range))
                    }
                } else {
                    let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
                    if let found = line.range(of: query, options: options) {
                        hits.append(SearchHit(url: url, lineNumber: lineNumber, line: line,
                                              range: NSRange(found, in: line)))
                    }
                }
                if hits.count >= limit { stop = true }
            }
        }
        return hits
    }

    // MARK: - Session persistence

    private let sessionKey = "openDocumentPaths"

    /// Stored relative to Documents wherever possible.
    ///
    /// iOS gives the app container a new UUID on every reinstall, so absolute
    /// paths saved by the previous copy point nowhere and every open tab was
    /// silently dropped — which for a sideloaded build means losing the session
    /// on each new build.
    private func persistSession() {
        let base = documentsURL.standardizedFileURL.path
        let paths = openDocuments.compactMap { $0.url?.standardizedFileURL.path }.map { path in
            path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : path
        }
        UserDefaults.standard.set(paths, forKey: sessionKey)
    }

    private func restoreSession() {
        let stored = UserDefaults.standard.stringArray(forKey: sessionKey) ?? []
        for entry in stored {
            // Absolute entries are from an older build of the app.
            let url = entry.hasPrefix("/")
                ? URL(fileURLWithPath: entry)
                : documentsURL.appendingPathComponent(entry)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            openDocuments.append(CodeDocument.placeholder(url: url))
        }
        // Only the tab that is about to be shown gets read from disk; the
        // others load when the user switches to them.
        activeDocumentID = openDocuments.first?.id
        activeDocument?.ensureLoaded()
    }

    // MARK: - First-run sample project

    private func seedSamplesIfNeeded() {
        let marker = documentsURL.appendingPathComponent(".codeforge-seeded")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        let welcome = documentsURL.appendingPathComponent("Welcome")
        try? FileManager.default.createDirectory(at: welcome, withIntermediateDirectories: true)
        for (name, contents) in SampleFiles.all {
            let url = welcome.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? contents.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        try? Data().write(to: marker)
    }
}
