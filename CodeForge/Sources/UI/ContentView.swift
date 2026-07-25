import SwiftUI
import UIKit

struct ContentView: View {

    @EnvironmentObject private var workspace: WorkspaceStore
    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var proxy = EditorProxy()

    @State private var showBrowser = false
    @State private var showSettings = false
    @State private var showProjectSearch = false
    @State private var showLanguagePicker = false
    @State private var showGoToLine = false
    @State private var showShareSheet = false
    @State private var showFindBar = false
    @State private var gotoLineText = ""

    private var theme: EditorTheme { settings.theme(for: colorScheme) }

    var body: some View {
        ZStack {
            Color(theme.background).ignoresSafeArea()

            VStack(spacing: 0) {
                if !workspace.openDocuments.isEmpty {
                    TabBarView(theme: theme)
                    Divider().background(Color(theme.indentGuide))
                }

                if showFindBar, let document = workspace.activeDocument {
                    FindBarView(theme: theme, proxy: proxy, language: document.language,
                                isPresented: $showFindBar)
                    Divider().background(Color(theme.indentGuide))
                }

                if let document = workspace.activeDocument {
                    CodeEditorView(document: document, settings: settings, theme: theme, proxy: proxy)
                        .id(document.id)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    WelcomeView(theme: theme, showBrowser: $showBrowser)
                }

                StatusBarView(theme: theme, proxy: proxy,
                              document: workspace.activeDocument,
                              showLanguagePicker: $showLanguagePicker,
                              showGoToLine: $showGoToLine)
            }
        }
        .preferredColorScheme(settings.followSystemAppearance ? nil : (theme.isDark ? .dark : .light))
        .safeAreaInset(edge: .top, spacing: 0) { toolbar }
        .sheet(isPresented: $showBrowser) {
            FileBrowserView(theme: theme).environmentObject(workspace)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(settings)
        }
        .sheet(isPresented: $showProjectSearch) {
            ProjectSearchView(theme: theme).environmentObject(workspace)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = workspace.activeDocument?.url {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(document: workspace.activeDocument, theme: theme)
        }
        .alert("Go to line", isPresented: $showGoToLine) {
            TextField("Line number", text: $gotoLineText).keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Go") {
                if let line = Int(gotoLineText) { proxy.goToLine(line) }
                gotoLineText = ""
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { workspace.errorMessage != nil },
                                    set: { if !$0 { workspace.errorMessage = nil } })) {
            Button("OK", role: .cancel) { workspace.errorMessage = nil }
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button { showBrowser = true } label: {
                Image(systemName: "folder")
            }
            .accessibilityLabel("Project browser")

            Button { workspace.newUntitledDocument() } label: {
                Image(systemName: "doc.badge.plus")
            }
            .accessibilityLabel("New file")

            Spacer(minLength: 0)

            Text(workspace.activeDocument?.name ?? "CodeForge")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(Color(theme.foreground))

            Spacer(minLength: 0)

            Button {
                showFindBar.toggle()
            } label: {
                Image(systemName: showFindBar ? "magnifyingglass.circle.fill" : "magnifyingglass")
            }
            .disabled(workspace.activeDocument == nil)
            .accessibilityLabel("Find in file")

            Menu {
                Button {
                    workspace.saveActiveDocument()
                } label: { Label("Save", systemImage: "square.and.arrow.down") }

                Button { proxy.toggleComment(language: workspace.activeDocument?.language ?? LanguageRegistry.plainText) } label: {
                    Label("Toggle comment", systemImage: "text.bubble")
                }
                Button { proxy.duplicateLine() } label: {
                    Label("Duplicate line", systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) { proxy.deleteLine() } label: {
                    Label("Delete line", systemImage: "trash")
                }

                Divider()

                Button { showProjectSearch = true } label: {
                    Label("Search in project", systemImage: "text.magnifyingglass")
                }
                Button { showGoToLine = true } label: {
                    Label("Go to line…", systemImage: "arrow.right.to.line")
                }
                Button { showLanguagePicker = true } label: {
                    Label("Language: \(workspace.activeDocument?.language.name ?? "—")",
                          systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Divider()

                Button { showShareSheet = true } label: {
                    Label("Share file", systemImage: "square.and.arrow.up")
                }
                .disabled(workspace.activeDocument?.url == nil)

                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .font(.system(size: 17, weight: .medium))
        .tint(Color(theme.accent))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(theme.gutterBackground).opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundColor(Color(theme.indentGuide))
        }
    }
}

// MARK: - Status bar

struct StatusBarView: View {
    let theme: EditorTheme
    @ObservedObject var proxy: EditorProxy
    let document: CodeDocument?
    @Binding var showLanguagePicker: Bool
    @Binding var showGoToLine: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button { showGoToLine = true } label: {
                Label("Ln \(proxy.caretLine), Col \(proxy.caretColumn)", systemImage: "text.cursor")
                    .labelStyle(.titleOnly)
            }
            if proxy.selectionLength > 0 {
                Text("(\(proxy.selectionLength) selected)")
                    .foregroundColor(Color(theme.gutterForeground))
            }
            Spacer()
            if let document {
                if document.isDirty {
                    Circle().fill(Color(theme.accent)).frame(width: 6, height: 6)
                }
                Text("\(document.lineCount) lines")
                    .foregroundColor(Color(theme.gutterForeground))
                Button { showLanguagePicker = true } label: {
                    Text(document.language.name)
                }
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .tint(Color(theme.accent))
        .foregroundColor(Color(theme.gutterActiveForeground))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(theme.gutterBackground))
        .overlay(alignment: .top) {
            Rectangle().frame(height: 0.5).foregroundColor(Color(theme.indentGuide))
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    let theme: EditorTheme
    @EnvironmentObject private var workspace: WorkspaceStore
    @Binding var showBrowser: Bool

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 54, weight: .light))
                .foregroundColor(Color(theme.accent))
            Text("CodeForge")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(theme.foreground))
            Text("A code editor for every language you carry around.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(theme.gutterForeground))
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button {
                    showBrowser = true
                } label: {
                    Label("Open a file", systemImage: "folder")
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    workspace.newUntitledDocument()
                } label: {
                    Label("New file", systemImage: "doc.badge.plus")
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.bordered)
            }
            .tint(Color(theme.accent))

            Text("\(LanguageRegistry.shared.all.count) languages · \(Themes.all.count) themes")
                .font(.caption2)
                .foregroundColor(Color(theme.gutterForeground))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(theme.background))
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
