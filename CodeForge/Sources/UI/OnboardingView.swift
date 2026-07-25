import SwiftUI

/// Three-card first-run guide. Short on purpose: it explains where files live,
/// what the extra keyboard row is for, and that saving is automatic — the three
/// things a first-time user otherwise has to discover by accident.
struct OnboardingView: View {

    let theme: EditorTheme
    @EnvironmentObject private var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Card {
        let icon: String
        let title: String
        let body: String
    }

    private var cards: [Card] {
        [
            Card(icon: "folder.fill",
                 title: L("Your files live here"),
                 body: L("The folder icon at the top left opens your files. Everything is saved inside this app and is also visible in the iPhone Files app.")),
            Card(icon: "keyboard",
                 title: L("The extra key row"),
                 body: L("Above the keyboard you get the symbols code needs — brackets, quotes, arrows — and they change to match the language you are editing.")),
            Card(icon: "checkmark.circle.fill",
                 title: L("Nothing to save manually"),
                 body: L("Your work is saved automatically as you type. The dot next to the file name means there are changes still being written."))
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(L("Skip")) { finish() }
                    .font(.subheadline)
                    .padding()
            }

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(Color(theme.accent))
                Text(L("Welcome to CodeForge"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(L("Three things to know"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)

            TabView(selection: $page) {
                ForEach(Array(cards.enumerated()), id: \.offset) { item in
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color(theme.accent).opacity(0.15))
                                .frame(width: 92, height: 92)
                            Image(systemName: item.element.icon)
                                .font(.system(size: 38, weight: .medium))
                                .foregroundColor(Color(theme.accent))
                        }
                        Text(item.element.title)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(item.element.body)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 8)
                    .tag(item.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 340)

            Spacer(minLength: 0)

            Button {
                if page < cards.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < cards.count - 1 ? L("Next") : L("Got it"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(theme.accent))
            .padding(.horizontal, 28)

            Text(L("Show this again from Help"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .background(Color(theme.background).ignoresSafeArea())
        .foregroundColor(Color(theme.foreground))
    }

    private func finish() {
        settings.hasSeenOnboarding = true
        dismiss()
    }
}

/// Task-oriented help, reachable any time from the menu.
struct HelpView: View {

    let theme: EditorTheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: EditorSettings
    @State private var showOnboarding = false

    private struct Item {
        let icon: String
        let title: String
        let body: String
    }

    private var sections: [(String, [Item])] {
        [
            (L("Basics"), [
                Item(icon: "folder", title: L("Open the file list"),
                     body: L("Tap the folder icon at the top left.")),
                Item(icon: "doc.badge.plus", title: L("Make a new file"),
                     body: L("Tap the page icon at the top, pick a type, and type a name — the extension is added for you.")),
                Item(icon: "rectangle.on.rectangle", title: L("Switch between open files"),
                     body: L("Use the tabs under the toolbar. Long-press a tab to close others."))
            ]),
            (L("Editing"), [
                Item(icon: "keyboard", title: L("Symbols above the keyboard"),
                     body: L("Tap them to insert brackets, quotes and arrows without switching keyboard pages.")),
                Item(icon: "arrow.right.to.line", title: L("Indent and unindent"),
                     body: L("The two arrow keys at the left of that row indent or unindent the current line or selection.")),
                Item(icon: "arrow.uturn.backward", title: L("Undo a mistake"),
                     body: L("Use the undo arrow in that row, or shake the phone.")),
                Item(icon: "textformat.size", title: L("Change the text size"),
                     body: L("Pinch with two fingers inside the editor, or set an exact size in Settings."))
            ]),
            (L("Finding things"), [
                Item(icon: "magnifyingglass", title: L("Search inside the open file"),
                     body: L("Tap the magnifier. Turn on .* for regular expressions.")),
                Item(icon: "text.magnifyingglass", title: L("Search every file"),
                     body: L("Menu ▸ Search all files."))
            ]),
            (L("Files and sharing"), [
                Item(icon: "square.and.arrow.down", title: L("Bring files in"),
                     body: L("File list ▸ + ▸ Import from Files. AirDrop and iCloud Drive both work.")),
                Item(icon: "square.and.arrow.up", title: L("Send a file out"),
                     body: L("Menu ▸ Share file."))
            ]),
            (L("Tips"), [
                Item(icon: "hand.draw", title: L("Rename"),
                     body: L("Swipe a file left in the list to rename, duplicate or delete it.")),
                Item(icon: "chevron.left.forwardslash.chevron.right", title: L("Language"),
                     body: L("The language is detected from the file extension; you can override it from the status bar."))
            ])
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(sections.enumerated()), id: \.offset) { section in
                    Section(section.element.0) {
                        ForEach(Array(section.element.1.enumerated()), id: \.offset) { row in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: row.element.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.element.title).font(.callout.weight(.semibold))
                                    Text(row.element.body)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label(L("Show the welcome guide again"), systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle(L("How to use CodeForge"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(theme: theme).environmentObject(settings)
            }
        }
    }
}
