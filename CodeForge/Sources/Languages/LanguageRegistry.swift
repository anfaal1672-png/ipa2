import Foundation

/// Central catalogue of every language the editor understands.
final class LanguageRegistry {
    static let shared = LanguageRegistry()

    private(set) var all: [LanguageDefinition] = []
    private var byID: [String: LanguageDefinition] = [:]
    private var byExtension: [String: LanguageDefinition] = [:]
    private var byFilename: [String: LanguageDefinition] = [:]
    private var byAlias: [String: LanguageDefinition] = [:]

    static let plainText = LanguageDefinition(id: "plaintext", name: "Plain Text",
                                              extensions: ["txt", "text", "log"], flavor: .plain)

    private init() {
        var definitions: [LanguageDefinition] = []
        definitions += Languages.cFamily
        definitions += Languages.jvm
        definitions += Languages.web
        definitions += Languages.scripting
        definitions += Languages.systems
        definitions += Languages.functional
        definitions += Languages.data
        definitions += Languages.shell
        definitions += Languages.scientific
        definitions += Languages.misc
        definitions.append(Self.plainText)

        all = definitions.sorted { $0.name.lowercased() < $1.name.lowercased() }
        for def in definitions {
            byID[def.id] = def
            byAlias[def.id] = def
            byAlias[def.name.lowercased()] = def
            for ext in def.extensions where byExtension[ext] == nil {
                byExtension[ext] = def
            }
            for ext in def.extensions where byAlias[ext] == nil {
                byAlias[ext] = def
            }
            for name in def.filenames {
                byFilename[name.lowercased()] = def
            }
        }
    }

    func language(id: String) -> LanguageDefinition? { byID[id] }

    /// Resolve by id, display name or extension — used for Markdown fences and
    /// the manual language picker.
    func language(named name: String) -> LanguageDefinition? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return nil }
        return byAlias[key]
    }

    func language(forFilename filename: String) -> LanguageDefinition {
        let name = (filename as NSString).lastPathComponent
        if let match = byFilename[name.lowercased()] { return match }
        let ext = (name as NSString).pathExtension.lowercased()
        if !ext.isEmpty, let match = byExtension[ext] { return match }
        // dotfiles: `.zshrc` → `zshrc`
        if name.hasPrefix("."), let match = byExtension[String(name.dropFirst()).lowercased()] {
            return match
        }
        return Self.plainText
    }

    func language(forContent content: String) -> LanguageDefinition? {
        guard content.hasPrefix("#!") else { return nil }
        let firstLine = content.prefix(while: { $0 != "\n" }).lowercased()
        for def in all {
            for shebang in def.shebangs where firstLine.contains(shebang) {
                return def
            }
        }
        return nil
    }

    /// Every extension the app claims to open, used by the file browser icons.
    var knownExtensions: Set<String> { Set(byExtension.keys) }
}

enum Languages {}
