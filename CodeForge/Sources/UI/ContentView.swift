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
    @State private var showNewFile = false
    @State private var showHelp = false
    @State private var showOnboarding = false
    @State private var showPreview = false
    @State private var gotoLineText = ""
    @State private var savedFlash = false

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
                    FindBarView(theme: theme, proxy: proxy, status: proxy.status,
                                language: document.language, isPresented: $showFindBar)
                    Divider().background(Color(theme.indentGuide))
                }

                if let document = workspace.activeDocument {
                    CodeEditorView(document: document, settings: settings, theme: theme, proxy: proxy)
                        .id(document.id)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    WelcomeView(theme: theme, showBrowser: $showBrowser, showNewFile: $showNewFile)
                }

                StatusBarView(theme: theme, status: proxy.status,
                              document: workspace.activeDocument,
                              showLanguagePicker: $showLanguagePicker,
                              showGoToLine: $showGoToLine)
            }

            if savedFlash {
                toast(L("Saved"), icon: "checkmark.circle.fill")
            }
        }
        .preferredColorScheme(settings.followSystemAppearance ? nil : (theme.isDark ? .dark : .light))
        .safeAreaInset(edge: .top, spacing: 0) { toolbar }
        .sheet(isPresented: $showBrowser) {
            FileBrowserView(theme: theme)
                .environmentObject(workspace)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(settings)
        }
        .sheet(isPresented: $showHelp) {
            HelpView(theme: theme).environmentObject(settings)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(theme: theme).environmentObject(settings)
        }
        .sheet(isPresented: $showProjectSearch) {
            ProjectSearchView(theme: theme)
                .environmentObject(workspace)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showNewFile) {
            NewFileSheet(folder: workspace.root) { name, contents in
                workspace.createFile(named: name, in: workspace.root, contents: contents)
            }
            .environmentObject(settings)
        }
        .sheet(isPresented: $showPreview) {
            if let document = workspace.activeDocument {
                PreviewView(document: document, theme: theme)
                    .environmentObject(settings)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = workspace.activeDocument?.url {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(document: workspace.activeDocument, theme: theme)
                .environmentObject(settings)
        }
        .alert(L("Go to line"), isPresented: $showGoToLine) {
            TextField(L("Line number"), text: $gotoLineText).keyboardType(.numberPad)
            Button(L("Cancel"), role: .cancel) { }
            Button(L("Go")) {
                if let line = Int(gotoLineText) { proxy.goToLine(line) }
                gotoLineText = ""
            }
        }
        .alert(L("Something went wrong"),
               isPresented: Binding(get: { workspace.errorMessage != nil },
                                    set: { if !$0 { workspace.errorMessage = nil } })) {
            Button(L("OK"), role: .cancel) { workspace.errorMessage = nil }
        } message: {
            Text(workspace.errorMessage ?? "")
        }
        .onAppear {
            workspace.flushEditor = { [weak proxy] in proxy?.flushText() }
            proxy.onRunRequested = { showPreview = true }
            if !settings.hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showOnboarding = true }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(icon: "folder", title: L("Project")) { showBrowser = true }
            toolbarButton(icon: "doc.badge.plus", title: L("New file")) { showNewFile = true }

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Text(workspace.activeDocument?.name ?? "CodeForge")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let document = workspace.activeDocument {
                    Text(document.isDirty ? L("Unsaved changes") : L("Saved"))
                        .font(.system(size: 9))
                        .foregroundColor(Color(document.isDirty ? theme.accent : theme.gutterForeground))
                }
            }
            .foregroundColor(Color(theme.foreground))

            Spacer(minLength: 4)

            toolbarButton(icon: showFindBar ? "magnifyingglass.circle.fill" : "magnifyingglass",
                          title: L("Find")) {
                showFindBar.toggle()
            }
            .disabled(workspace.activeDocument == nil)

            toolbarButton(icon: previewIcon, title: previewTitle) {
                runPreview()
            }
            .disabled(workspace.activeDocument == nil)

            Menu {
                Button {
                    proxy.flushText()
                    workspace.saveActiveDocument()
                    flashSaved()
                } label: { Label(L("Save"), systemImage: "square.and.arrow.down") }
                    .disabled(workspace.activeDocument == nil)

                Button { proxy.undo() } label: { Label(L("Undo"), systemImage: "arrow.uturn.backward") }
                Button { proxy.redo() } label: { Label(L("Redo"), systemImage: "arrow.uturn.forward") }

                Divider()

                Button {
                    proxy.toggleComment(language: workspace.activeDocument?.language ?? LanguageRegistry.plainText)
                } label: { Label(L("Toggle comment"), systemImage: "text.bubble") }
                Button { proxy.duplicateLine() } label: {
                    Label(L("Duplicate line"), systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) { proxy.deleteLine() } label: {
                    Label(L("Delete line"), systemImage: "trash")
                }

                Divider()

                Button { showProjectSearch = true } label: {
                    Label(L("Search in project"), systemImage: "text.magnifyingglass")
                }
                Button { showGoToLine = true } label: {
                    Label(L("Go to line…"), systemImage: "arrow.right.to.line")
                }
                Button { showLanguagePicker = true } label: {
                    Label("\(L("Language")): \(workspace.activeDocument?.language.name ?? "—")",
                          systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Divider()

                Button {
                    runPreview()
                } label: {
                    Label(previewTitle, systemImage: previewIcon)
                }
                .disabled(workspace.activeDocument == nil)

                Button {
                    proxy.flushText()
                    workspace.saveActiveDocument()
                    showShareSheet = true
                } label: {
                    Label(L("Share file"), systemImage: "square.and.arrow.up")
                }
                .disabled(workspace.activeDocument?.url == nil)

                Button { showHelp = true } label: {
                    Label(L("Help"), systemImage: "questionmark.circle")
                }
                Button { showSettings = true } label: {
                    Label(L("Settings"), systemImage: "gearshape")
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ellipsis.circle").font(.system(size: 18, weight: .medium))
                    Text(L("Menu")).font(.system(size: 9))
                }
                .frame(minWidth: 46)
            }
        }
        .tint(Color(theme.accent))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Color(theme.gutterBackground).opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundColor(Color(theme.indentGuide))
        }
    }

    /// The same button reads "Run" for a language the app can execute and
    /// "Preview" for one it can only render — the distinction matters enough
    /// that the button should say which one is about to happen.
    private var previewKind: PreviewKind? {
        workspace.activeDocument.map { PreviewKind.kind(for: $0.language) }
    }

    private var isRunnable: Bool {
        switch previewKind {
        case .runtime, .javascript: return true
        default: return false
        }
    }

    private var previewTitle: String { isRunnable ? L("Run") : L("Preview") }

    private var previewIcon: String { isRunnable ? "play.fill" : "eye" }

    private func runPreview() {
        proxy.flushText()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showPreview = true
    }

    /// Icon plus caption: a bare glyph is guessable only if you already know the
    /// app, and this row is the first thing a new user meets.
    private func toolbarButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(minWidth: 46)
        }
        .accessibilityLabel(title)
    }

    private func toast(_ text: String, icon: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(text).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(Color(theme.currentLine))
                    .overlay(Capsule().stroke(Color(theme.indentGuide), lineWidth: 0.5))
            )
            .foregroundColor(Color(theme.foreground))
            .padding(.bottom, 90)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private func flashSaved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.2)) { savedFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeIn(duration: 0.25)) { savedFlash = false }
        }
    }
}

// MARK: - Status bar

struct StatusBarView: View {
    let theme: EditorTheme
    @ObservedObject var status: EditorStatus
    let document: CodeDocument?
    @Binding var showLanguagePicker: Bool
    @Binding var showGoToLine: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button { showGoToLine = true } label: {
                Text("\(L("Ln")) \(status.caretLine) · \(L("Col")) \(status.caretColumn)")
            }
            if status.selectionLength > 0 {
                Text("\(status.selectionLength) \(L("selected"))")
                    .foregroundColor(Color(theme.gutterForeground))
            }
            Spacer()
            if let document {
                if document.isDirty {
                    Circle().fill(Color(theme.accent)).frame(width: 6, height: 6)
                }
                Text("\(document.lineCount) \(L("lines"))")
                    .foregroundColor(Color(theme.gutterForeground))
                Button { showLanguagePicker = true } label: {
                    HStack(spacing: 3) {
                        // A play glyph next to the language is the quietest way
                        // to answer "can this file actually run?"
                        if PreviewKind.kind(for: document.language).isExecutable {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(theme.accent))
                        }
                        Text(document.language.name)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 7))
                    }
                }
                .accessibilityLabel(PreviewKind.kind(for: document.language).isExecutable
                                    ? "\(document.language.name) — \(L("Runnable"))"
                                    : document.language.name)
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
    @Binding var showNewFile: Bool

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 54, weight: .light))
                .foregroundColor(Color(theme.accent))
            Text("CodeForge")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(theme.foreground))
            Text(L("A code editor for every language you carry around."))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(theme.gutterForeground))
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button {
                    showNewFile = true
                } label: {
                    Label(L("New file"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: 280)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showBrowser = true
                } label: {
                    Label(L("Open a file"), systemImage: "folder")
                        .frame(maxWidth: 280)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)

                Button {
                    openSample()
                } label: {
                    Label(L("Open the sample project"), systemImage: "sparkles")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(theme.accent))
                .padding(.top, 4)
            }
            .tint(Color(theme.accent))

            Text("\(LanguageRegistry.shared.all.count) \(L("languages")) · \(Themes.all.count) \(L("themes"))")
                .font(.caption2)
                .foregroundColor(Color(theme.gutterForeground))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(theme.background))
    }

    private func openSample() {
        let readme = workspace.documentsURL
            .appendingPathComponent("Welcome")
            .appendingPathComponent("README.md")
        if FileManager.default.fileExists(atPath: readme.path) {
            workspace.open(url: readme)
        } else {
            showBrowser = true
        }
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
