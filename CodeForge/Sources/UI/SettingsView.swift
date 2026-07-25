import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    NavigationLink {
                        ThemeGalleryView(selection: $settings.themeID, title: "Theme")
                            .environmentObject(settings)
                    } label: {
                        LabeledContent("Theme", value: Themes.theme(id: settings.themeID).name)
                    }

                    Toggle("Follow system light/dark", isOn: $settings.followSystemAppearance)

                    if settings.followSystemAppearance {
                        NavigationLink {
                            ThemeGalleryView(selection: $settings.lightThemeID, title: "Light theme")
                                .environmentObject(settings)
                        } label: {
                            LabeledContent("Light theme",
                                           value: Themes.theme(id: settings.lightThemeID).name)
                        }
                    }
                }

                Section("Typography") {
                    Picker("Font", selection: $settings.fontName) {
                        ForEach(EditorSettings.FontChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice.rawValue)
                        }
                    }
                    Stepper(value: $settings.fontSize, in: 9...30, step: 1) {
                        LabeledContent("Size", value: "\(Int(settings.fontSize)) pt")
                    }
                    HStack {
                        Text("Preview")
                        Spacer()
                        Text("let x = 42")
                            .font(Font(settings.font()))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Editing") {
                    Stepper(value: $settings.tabWidth, in: 1...8) {
                        LabeledContent("Tab width", value: "\(settings.tabWidth)")
                    }
                    Toggle("Insert spaces instead of tabs", isOn: $settings.useSpaces)
                    Toggle("Auto indent", isOn: $settings.autoIndent)
                    Toggle("Auto close brackets & quotes", isOn: $settings.autoCloseBrackets)
                    Toggle("Auto save", isOn: $settings.autoSave)
                }

                Section("Display") {
                    Toggle("Syntax highlighting", isOn: $settings.syntaxHighlighting)
                    Toggle("Line numbers", isOn: $settings.showLineNumbers)
                    Toggle("Wrap long lines", isOn: $settings.wrapLines)
                    Toggle("Highlight current line", isOn: $settings.highlightCurrentLine)
                    Toggle("Indentation guides", isOn: $settings.showIndentGuides)
                    Toggle("Code keyboard row", isOn: $settings.showKeyboardToolbar)
                }

                Section("Languages") {
                    NavigationLink {
                        LanguageListView()
                    } label: {
                        LabeledContent("Supported languages",
                                       value: "\(LanguageRegistry.shared.all.count)")
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                    LabeledContent("Build", value: Bundle.main.buildNumber)
                } header: {
                    Text("About")
                } footer: {
                    Text("CodeForge — an offline code editor. Files live in the app's Documents folder and are reachable from the Files app.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ThemeGalleryView: View {
    @Binding var selection: String
    let title: String

    var body: some View {
        List(Themes.all) { theme in
            Button {
                selection = theme.id
            } label: {
                HStack(spacing: 12) {
                    ThemeSwatch(theme: theme)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.name).foregroundColor(.primary)
                        Text(theme.isDark ? "Dark" : "Light")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selection == theme.id {
                        Image(systemName: "checkmark").foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemeSwatch: View {
    let theme: EditorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            line(widths: [10, 26, 18], types: [.keyword, .function, .string])
            line(widths: [16, 14, 30], types: [.type, .operator, .comment])
            line(widths: [8, 22, 12], types: [.number, .property, .constant])
        }
        .padding(6)
        .frame(width: 72, height: 52, alignment: .leading)
        .background(Color(theme.background))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(theme.indentGuide), lineWidth: 1)
        )
    }

    private func line(widths: [CGFloat], types: [TokenType]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(zip(widths, types).enumerated()), id: \.offset) { item in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(theme.color(for: item.element.1)))
                    .frame(width: item.element.0, height: 4)
            }
        }
    }
}

struct LanguageListView: View {
    @State private var filter = ""

    private var languages: [LanguageDefinition] {
        let all = LanguageRegistry.shared.all
        guard !filter.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(filter)
                || $0.extensions.contains { $0.localizedCaseInsensitiveContains(filter) }
        }
    }

    var body: some View {
        List(languages, id: \.id) { language in
            VStack(alignment: .leading, spacing: 3) {
                Text(language.name)
                if !language.extensions.isEmpty {
                    Text(language.extensions.map { ".\($0)" }.joined(separator: "  "))
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .searchable(text: $filter, prompt: "Search languages")
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LanguagePickerView: View {
    let document: CodeDocument?
    let theme: EditorTheme
    @Environment(\.dismiss) private var dismiss
    @State private var filter = ""

    private var languages: [LanguageDefinition] {
        let all = LanguageRegistry.shared.all
        guard !filter.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        NavigationStack {
            List(languages, id: \.id) { language in
                Button {
                    document?.languageOverride = language
                    dismiss()
                } label: {
                    HStack {
                        Text(language.name).foregroundColor(.primary)
                        Spacer()
                        if document?.language.id == language.id {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .searchable(text: $filter, prompt: "Search languages")
            .navigationTitle("Syntax")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Auto") {
                        document?.languageOverride = nil
                        dismiss()
                    }
                }
            }
        }
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
