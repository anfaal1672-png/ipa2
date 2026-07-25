import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Language")) {
                    Picker(L("App language"), selection: Binding(
                        get: { settings.appLanguage },
                        set: { settings.appLanguage = $0 })) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                Section(L("Appearance")) {
                    NavigationLink {
                        ThemeGalleryView(selection: $settings.themeID, title: L("Theme"))
                            .environmentObject(settings)
                    } label: {
                        LabeledContent(L("Theme"), value: Themes.theme(id: settings.themeID).name)
                    }

                    Toggle(L("Follow system light/dark"), isOn: $settings.followSystemAppearance)

                    if settings.followSystemAppearance {
                        NavigationLink {
                            ThemeGalleryView(selection: $settings.lightThemeID, title: L("Light theme"))
                                .environmentObject(settings)
                        } label: {
                            LabeledContent(L("Light theme"),
                                           value: Themes.theme(id: settings.lightThemeID).name)
                        }
                    }
                }

                Section(L("Typography")) {
                    Picker(L("Font"), selection: $settings.fontName) {
                        ForEach(EditorSettings.FontChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice.rawValue)
                        }
                    }
                    HStack {
                        Text(L("Size"))
                        Spacer()
                        Button {
                            settings.fontSize = max(9, settings.fontSize - 1)
                        } label: {
                            Image(systemName: "minus.circle").font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        Text("\(Int(settings.fontSize))")
                            .font(.body.monospacedDigit())
                            .frame(minWidth: 32)
                        Button {
                            settings.fontSize = min(30, settings.fontSize + 1)
                        } label: {
                            Image(systemName: "plus.circle").font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Text(L("Preview"))
                        Spacer()
                        Text("let x = 42")
                            .font(.system(size: CGFloat(settings.fontSize), design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Toggle(L("Pinch to change text size"), isOn: $settings.pinchToZoom)
                }

                Section(L("Editing")) {
                    Stepper(value: $settings.tabWidth, in: 1...8) {
                        LabeledContent(L("Tab width"), value: "\(settings.tabWidth)")
                    }
                    Toggle(L("Insert spaces instead of tabs"), isOn: $settings.useSpaces)
                    Toggle(L("Auto indent"), isOn: $settings.autoIndent)
                    Toggle(L("Auto close brackets & quotes"), isOn: $settings.autoCloseBrackets)
                    Toggle(L("Auto save"), isOn: $settings.autoSave)
                }

                Section(L("Display")) {
                    Toggle(L("Syntax highlighting"), isOn: $settings.syntaxHighlighting)
                    Toggle(L("Line numbers"), isOn: $settings.showLineNumbers)
                    Toggle(L("Wrap long lines"), isOn: $settings.wrapLines)
                    Toggle(L("Highlight current line"), isOn: $settings.highlightCurrentLine)
                    Toggle(L("Indentation guides"), isOn: $settings.showIndentGuides)
                    Toggle(L("Code keyboard row"), isOn: $settings.showKeyboardToolbar)
                }

                Section(L("Languages")) {
                    NavigationLink {
                        LanguageListView()
                    } label: {
                        LabeledContent(L("Supported languages"),
                                       value: "\(LanguageRegistry.shared.all.count)")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label(L("Reset to defaults"), systemImage: "arrow.counterclockwise")
                    }
                }

                Section {
                    LabeledContent(L("Version"), value: Bundle.main.shortVersion)
                    LabeledContent(L("Build"), value: Bundle.main.buildNumber)
                } header: {
                    Text(L("About"))
                } footer: {
                    Text(L("CodeForge — an offline code editor. Files live in the app's Documents folder and are reachable from the Files app."))
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .confirmationDialog(L("Reset to defaults"), isPresented: $showResetConfirmation,
                                titleVisibility: .visible) {
                Button(L("Reset to defaults"), role: .destructive) { settings.resetToDefaults() }
                Button(L("Cancel"), role: .cancel) { }
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
                        Text(theme.isDark ? L("Dark") : L("Light"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selection == theme.id {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
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
        .searchable(text: $filter, prompt: L("Search languages"))
        .navigationTitle(L("Supported languages"))
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
            .searchable(text: $filter, prompt: L("Search languages"))
            .navigationTitle(L("Syntax"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L("Auto")) {
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
