import Foundation
import UniformTypeIdentifiers

/// A node in the project tree. Children are loaded lazily and cached.
final class FileItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let isDirectory: Bool
    private(set) var children: [FileItem]?

    init(url: URL, isDirectory: Bool) {
        self.url = url.standardizedFileURL
        self.isDirectory = isDirectory
        self.id = self.url.path
    }

    var name: String { url.lastPathComponent }

    var language: LanguageDefinition { LanguageRegistry.shared.language(forFilename: name) }

    /// Cached: a list row reads size and language while scrolling, and a stat
    /// per property access means several syscalls per row per frame.
    /// `invalidate()` clears it, which is what a refresh does anyway.
    private var cachedAttributes: [FileAttributeKey: Any]?

    private var attributes: [FileAttributeKey: Any] {
        if let cachedAttributes { return cachedAttributes }
        let loaded = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        cachedAttributes = loaded
        return loaded
    }

    var byteSize: Int64 { (attributes[.size] as? NSNumber)?.int64Value ?? 0 }

    var modifiedAt: Date { attributes[.modificationDate] as? Date ?? .distantPast }

    @discardableResult
    func loadChildren(force: Bool = false) -> [FileItem] {
        if let children, !force { return children }
        guard isDirectory else {
            children = []
            return []
        }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles])) ?? []

        let items = contents.map { child -> FileItem in
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return FileItem(url: child, isDirectory: isDir)
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        children = items
        return items
    }

    func invalidate() {
        children = nil
        cachedAttributes = nil
    }

    /// SF Symbol shown next to the file in the browser.
    var iconName: String {
        if isDirectory { return "folder.fill" }
        switch language.id {
        case "markdown", "rst": return "doc.richtext"
        case "json", "yaml", "toml", "ini", "dotenv", "xml", "csv": return "list.bullet.rectangle"
        case "html", "css", "scss", "less", "stylus", "vue", "svelte": return "globe"
        case "shell", "fish", "powershell", "batch", "makefile", "dockerfile": return "terminal"
        case "sql", "plsql": return "cylinder.split.1x2"
        case "diff": return "plusminus"
        case "plaintext": return "doc.text"
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
