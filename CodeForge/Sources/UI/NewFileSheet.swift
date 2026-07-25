import SwiftUI

/// Beginner-friendly file creation: pick a type, type a plain name, see the
/// resulting file name before committing. No need to know what an extension is.
struct NewFileSheet: View {

    let folder: FileItem
    let onCreate: (String, String) -> Void      // (file name, initial contents)

    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss

    @State private var selected: FileTemplate = FileTemplate.all[1]
    @State private var name: String = ""
    @State private var customExtension: String = ""
    @State private var useExample = true
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(FileTemplate.all) { template in
                        Button {
                            selected = template
                            if name.isEmpty { name = template.suggestedName }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.icon)
                                    .frame(width: 24)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name).foregroundColor(.primary)
                                    if !template.fileExtension.isEmpty {
                                        Text(".\(template.fileExtension)")
                                            .font(.caption2.monospaced())
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if selected.id == template.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    Text(L("Choose a type"))
                } footer: {
                    Text(L("Pick a file type; the extension is added for you."))
                }

                Section(L("Name")) {
                    TextField(L("File name"), text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(create)

                    if selected.isCustom {
                        TextField("txt", text: $customExtension)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    LabeledContent(L("will be saved as")) {
                        Text(finalName.isEmpty ? "—" : finalName)
                            .font(.callout.monospaced())
                            .foregroundColor(.secondary)
                    }
                }

                if !selected.body.isEmpty {
                    Section {
                        Toggle(L("Start from an example"), isOn: $useExample)
                    }
                }
            }
            .navigationTitle(L("What do you want to make?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Create"), action: create)
                        .disabled(trimmedName.isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if name.isEmpty { name = selected.suggestedName }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nameFocused = true }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedExtension: String {
        let ext = selected.isCustom ? customExtension : selected.fileExtension
        return ext.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    private var finalName: String {
        let base = trimmedName
        guard !base.isEmpty else { return "" }
        if base.contains(".") { return base }              // the user typed their own
        guard !resolvedExtension.isEmpty else { return base }
        return "\(base).\(resolvedExtension)"
    }

    private func create() {
        guard !finalName.isEmpty else { return }
        let contents = (useExample && !selected.body.isEmpty) ? selected.body : ""
        onCreate(finalName, contents)
        dismiss()
    }
}
