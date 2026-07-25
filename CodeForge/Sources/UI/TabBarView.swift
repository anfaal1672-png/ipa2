import SwiftUI

/// Horizontal strip of open buffers.
struct TabBarView: View {

    let theme: EditorTheme
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workspace.openDocuments) { document in
                        TabChip(document: document,
                                theme: theme,
                                isActive: document.id == workspace.activeDocumentID,
                                onSelect: { workspace.activeDocumentID = document.id },
                                onClose: { workspace.close(document) })
                            .id(document.id)
                            .contextMenu {
                                Button {
                                    workspace.openDocuments
                                        .filter { $0.id != document.id }
                                        .forEach { workspace.close($0) }
                                } label: { Label("Close others", systemImage: "xmark.square") }
                                Button(role: .destructive) {
                                    workspace.closeAll()
                                } label: { Label("Close all", systemImage: "xmark.square.fill") }
                                if let url = document.url {
                                    Button {
                                        UIPasteboard.general.string = url.lastPathComponent
                                    } label: { Label("Copy name", systemImage: "doc.on.doc") }
                                }
                            }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(Color(theme.gutterBackground))
            .onChange(of: workspace.activeDocumentID) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { scrollProxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

private struct TabChip: View {
    @ObservedObject var document: CodeDocument
    let theme: EditorTheme
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundColor(Color(theme.accent).opacity(isActive ? 1 : 0.55))
            Text(document.name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
            if document.isDirty {
                Circle().fill(Color(theme.accent)).frame(width: 5, height: 5)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(isActive ? theme.currentLine : theme.background))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(isActive ? theme.accent : theme.indentGuide).opacity(isActive ? 0.7 : 1),
                        lineWidth: isActive ? 1 : 0.5)
        )
        .foregroundColor(Color(isActive ? theme.foreground : theme.gutterForeground))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var iconName: String {
        LanguageRegistry.shared.language(forFilename: document.name).flavor == .plain
            ? "doc.text" : "chevron.left.forwardslash.chevron.right"
    }
}
