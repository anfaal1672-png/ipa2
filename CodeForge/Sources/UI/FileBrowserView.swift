import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {

    let theme: EditorTheme
    @EnvironmentObject private var workspace: WorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var filter = ""
    @State private var newItemTarget: FileItem?
    @State private var newItemIsFolder = false
    @State private var newItemName = ""
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var pendingDeletion: FileItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OutlineRows(items: filteredChildren(of: workspace.root),
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
                                onNewFile: { folder in
                                    newItemTarget = folder
                                    newItemIsFolder = false
                                    newItemName = ""
                                },
                                onNewFolder: { folder in
                                    newItemTarget = folder
                                    newItemIsFolder = true
                                    newItemName = ""
                                })
                } header: {
                    Text("Documents")
                } footer: {
                    Text("This folder is visible in the Files app under “On My iPhone › CodeForge”.")
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $filter, prompt: "Filter files")
            .navigationTitle("Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newItemTarget = workspace.root
                            newItemIsFolder = false
                            newItemName = ""
                        } label: { Label("New file", systemImage: "doc.badge.plus") }
                        Button {
                            newItemTarget = workspace.root
                            newItemIsFolder = true
                            newItemName = ""
                        } label: { Label("New folder", systemImage: "folder.badge.plus") }
                        Button { showImporter = true } label: {
                            Label("Import from Files", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button { workspace.refreshTree() } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: { Image(systemName: "plus") }
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.item],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): workspace.importFiles(from: urls)
                case .failure(let error): workspace.errorMessage = error.localizedDescription
                }
            }
            .alert(newItemIsFolder ? "New folder" : "New file",
                   isPresented: Binding(get: { newItemTarget != nil },
                                        set: { if !$0 { newItemTarget = nil } })) {
                TextField(newItemIsFolder ? "Folder name" : "name.ext", text: $newItemName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) { newItemTarget = nil }
                Button("Create") {
                    let name = newItemName.trimmingCharacters(in: .whitespaces)
                    if let target = newItemTarget, !name.isEmpty {
                        if newItemIsFolder {
                            workspace.createFolder(named: name, in: target)
                        } else {
                            workspace.createFile(named: name, in: target)
                            dismiss()
                        }
                    }
                    newItemTarget = nil
                }
            }
            .alert("Rename", isPresented: Binding(get: { renameTarget != nil },
                                                  set: { if !$0 { renameTarget = nil } })) {
                TextField("New name", text: $renameText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Rename") {
                    if let target = renameTarget {
                        let name = renameText.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty, name != target.name { workspace.rename(target, to: name) }
                    }
                    renameTarget = nil
                }
            }
            .confirmationDialog("Delete “\(pendingDeletion?.name ?? "")”?",
                                isPresented: Binding(get: { pendingDeletion != nil },
                                                     set: { if !$0 { pendingDeletion = nil } }),
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item = pendingDeletion { workspace.delete(item) }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            }
        }
    }

    private func filteredChildren(of item: FileItem) -> [FileItem] {
        item.loadChildren()
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
                    .font(.system(size: 13))
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).lineLimit(1)
                    if !item.isDirectory {
                        Text("\(item.language.name) · \(formatted(item.byteSize))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.leading, CGFloat(level) * 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { onRename(item) } label: { Label("Rename", systemImage: "pencil") }
                .tint(.orange)
            Button { onDuplicate(item) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                .tint(.blue)
        }
        .contextMenu {
            if item.isDirectory {
                Button { onNewFile(item) } label: { Label("New file here", systemImage: "doc.badge.plus") }
                Button { onNewFolder(item) } label: { Label("New folder here", systemImage: "folder.badge.plus") }
                Divider()
            }
            Button { onRename(item) } label: { Label("Rename", systemImage: "pencil") }
            Button { onDuplicate(item) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button(role: .destructive) { onDelete(item) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
