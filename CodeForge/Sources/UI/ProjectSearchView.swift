import SwiftUI

/// Grep across every file in the workspace.
struct ProjectSearchView: View {

    let theme: EditorTheme
    @EnvironmentObject private var workspace: WorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var caseSensitive = false
    @State private var useRegex = false
    @State private var hits: [WorkspaceStore.SearchHit] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Toggle("Aa", isOn: $caseSensitive).toggleStyle(.button)
                    Toggle(".*", isOn: $useRegex).toggleStyle(.button)
                    Spacer()
                    if isSearching { ProgressView().controlSize(.small) }
                    Text(hasSearched ? "\(hits.count) matches" : "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                List {
                    ForEach(groupedHits, id: \.0) { path, fileHits in
                        Section(URL(fileURLWithPath: path).lastPathComponent) {
                            ForEach(fileHits) { hit in
                                Button {
                                    workspace.open(url: hit.url)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(hit.line.trimmingCharacters(in: .whitespaces))
                                            .font(.system(size: 12, design: .monospaced))
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                        Text("line \(hit.lineNumber)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if hasSearched && hits.isEmpty && !isSearching {
                        ContentUnavailableFallback(text: "No matches")
                    }
                }
            }
            .navigationTitle("Search in project")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search all files")
            .onSubmit(of: .search) { runSearch() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var groupedHits: [(String, [WorkspaceStore.SearchHit])] {
        Dictionary(grouping: hits, by: { $0.url.path })
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private func runSearch() {
        let text = query
        guard !text.isEmpty else { hits = []; hasSearched = false; return }
        isSearching = true
        let store = workspace
        Task {
            let results = store.search(text, caseSensitive: caseSensitive, useRegex: useRegex)
            await MainActor.run {
                hits = results
                isSearching = false
                hasSearched = true
            }
        }
    }
}

/// `ContentUnavailableView` needs iOS 17; this keeps the deployment target low.
struct ContentUnavailableFallback: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
            Text(text).foregroundColor(.secondary)
        }
    }
}
