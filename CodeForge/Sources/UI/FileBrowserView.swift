import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {

    let theme: EditorTheme
    @EnvironmentObject private var workspace: WorkspaceStore
    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss

    @State private var filter = ""
    @State private var newFileFolder: FileItem?
    @State private var newFolderTarget: FileItem?
    @State private var newFolderName = ""
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var pendingDeletion: FileItem?

    var body: some View {
        NavigationStack {
            Group {
                if workspace.root.loadChildren().isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .navigationTitle(L("Project"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Done")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newFileFolder = workspace.root
                        } label: { Label(L("New file"), systemImage: "doc.badge.plus") }
                        Button {
                            newFolderTarget = workspace.root
                            newFolderName = ""
                        } label: { Label(L("New folder"), systemImage: "folder.badge.plus") }
                        Button { importFromFiles() } label: {
                            Label(L("Import from Files"), systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button { workspace.refreshTree() } label: {
                            Label(L("Refresh"), systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 18))
                    }
                }
            }
            .sheet(item: $newFileFolder) { folder in
                NewFileSheet(folder: folder) { name, contents in
                    workspace.createFile(named: name, in: folder, contents: contents)
                    dismiss()
                }
                .environmentObject(settings)
            }
            .alert(L("New folder"),
                   isPresented: Binding(get: { newFolderTarget != nil },
                                        set: { if !$0 { newFolderTarget = nil } })) {
                TextField(L("Name"), text: $newFolderName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button(L("Cancel"), role: .cancel) { newFolderTarget = nil }
                Button(L("Create")) {
                    let name = newFolderName.trimmingCharacters(in: .whitespaces)
                    if let target = newFolderTarget, !name.isEmpty {
                        workspace.createFolder(named: name, in: target)
                    }
                    newFolderTarget = nil
                }
            }
            .alert(L("Rename"), isPresented: Binding(get: { renameTarget != nil },
                                                     set: { if !$0 { renameTarget = nil } })) {
                TextField(L("Name"), text: $renameText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button(L("Cancel"), role: .cancel) { renameTarget = nil }
                Button(L("Rename")) {
                    if let target = renameTarget {
                        let name = renameText.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty, name != target.name { workspace.rename(target, to: name) }
                    }
                    renameTarget = nil
                }
            }
            .confirmationDialog("\(L("Delete this item?"))\n「\(pendingDeletion?.name ?? "")」",
                                isPresented: Binding(get: { pendingDeletion != nil },
                                                     set: { if !$0 { pendingDeletion = nil } }),
                                titleVisibility: .visible) {
                Button(L("Delete"), role: .destructive) {
                    if let item = pendingDeletion { workspace.delete(item) }
                    pendingDeletion = nil
                }
                Button(L("Cancel"), role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(L("This cannot be undone."))
            }
        }
        // Attached to the navigation stack rather than to its content: the
        // content already carries two alerts and a confirmation dialog, and
        // stacking a third on the same view is how presentations get dropped.
        // Errors have to appear here anyway — an alert on the editor screen
        // behind this sheet never shows.
        .alert(L("Something went wrong"),
               isPresented: Binding(get: { workspace.errorMessage != nil },
                                    set: { if !$0 { workspace.errorMessage = nil } })) {
            Button(L("OK"), role: .cancel) { workspace.errorMessage = nil }
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    private var fileList: some View {
        List {
            Section {
                OutlineRows(items: workspace.root.loadChildren(),
                            level: 0,
                            filter: filter,
                            onOpen: { item in
                                workspace.open(item)
                                dismiss()
                            },
                            onRename: { item in
                                renameTarget = item
                                renameText = item.name
                            },
                            onDelete: { item in pendingDeletion = item },
                            onDuplicate: { workspace.duplicate($0) },
                            onNewFile: { folder in newFileFolder = folder },
                            onNewFolder: { folder in
                                newFolderTarget = folder
                                newFolderName = ""
                            })
            } header: {
                Text(L("Documents"))
            } footer: {
                Text(L("This folder is visible in the Files app under “On My iPhone › CodeForge”."))
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $filter, prompt: L("Filter files"))
    }

    /// Imports, then opens what was imported — landing on the file is what the
    /// user was after, and it also makes the outcome visible.
    private func importFromFiles() {
        DocumentImporter.shared.present { urls in
            guard !urls.isEmpty else { return }
            let imported = workspace.importFiles(from: urls)
            if let first = imported.first {
                workspace.open(url: first)
                dismiss()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)
            Text(L("No files yet")).font(.headline)
            Text(L("Tap + to make your first file."))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                newFileFolder = workspace.root
            } label: {
                Label(L("New file"), systemImage: "doc.badge.plus")
                    .frame(maxWidth: 240)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
        }
        .padding(40)
    }
}

/// Recursive rows. SwiftUI's `OutlineGroup` insists on a fully materialised
/// tree, so the rows expand lazily through the workspace's expansion set.
private struct OutlineRows: View {
    let items: [FileItem]
    let level: Int
    let filter: String
    let onOpen: (FileItem) -> Void
    let onRename: (FileItem) -> Void
    let onDelete: (FileItem) -> Void
    let onDuplicate: (FileItem) -> Void
    let onNewFile: (FileItem) -> Void
    let onNewFolder: (FileItem) -> Void

    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ForEach(visibleItems, id: \.id) { item in
            row(for: item)
            if item.isDirectory, workspace.expandedFolders.contains(item.url.path) {
                OutlineRows(items: item.loadChildren(), level: level + 1, filter: filter,
                            onOpen: onOpen, onRename: onRename, onDelete: onDelete,
                            onDuplicate: onDuplicate, onNewFile: onNewFile, onNewFolder: onNewFolder)
            }
        }
    }

    private var visibleItems: [FileItem] {
        guard !filter.isEmpty else { return items }
        return items.filter { item in
            item.isDirectory || item.name.localizedCaseInsensitiveContains(filter)
        }
    }

    @ViewBuilder
    private func row(for item: FileItem) -> some View {
        Button {
            if item.isDirectory {
                if workspace.expandedFolders.contains(item.url.path) {
                    workspace.expandedFolders.remove(item.url.path)
                } else {
                    workspace.expandedFolders.insert(item.url.path)
                    item.loadChildren(force: true)
                }
            } else {
                onOpen(item)
            }
        } label: {
            HStack(spacing: 8) {
                if item.isDirectory {
                    Image(systemName: workspace.expandedFolders.contains(item.url.path)
                          ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }
                Image(systemName: item.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).lineLimit(1)
                    if !item.isDirectory {
                        Text("\(item.language.name) · \(formatted(item.byteSize))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.leading, CGFloat(level) * 14)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete(item) } label: {
                Label(L("Delete"), systemImage: "trash")
            }
            Button { onRename(item) } label: { Label(L("Rename"), systemImage: "pencil") }
                .tint(.orange)
            Button { onDuplicate(item) } label: {
                Label(L("Duplicate"), systemImage: "plus.square.on.square")
            }
            .tint(.blue)
        }
        .contextMenu {
            if item.isDirectory {
                Button { onNewFile(item) } label: {
                    Label(L("New file here"), systemImage: "doc.badge.plus")
                }
                Button { onNewFolder(item) } label: {
                    Label(L("New folder here"), systemImage: "folder.badge.plus")
                }
                Divider()
            }
            Button { onRename(item) } label: { Label(L("Rename"), systemImage: "pencil") }
            Button { onDuplicate(item) } label: {
                Label(L("Duplicate"), systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) { onDelete(item) } label: {
                Label(L("Delete"), systemImage: "trash")
            }
        }
    }

    private func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
