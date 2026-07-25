import SwiftUI

/// In-file find & replace, docked under the tab bar.
struct FindBarView: View {

    let theme: EditorTheme
    @ObservedObject var proxy: EditorProxy
    let language: LanguageDefinition
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var replacement = ""
    @State private var options = FindOptions()
    @State private var showReplace = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    withAnimation { showReplace.toggle() }
                } label: {
                    Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 16)
                }

                field(text: $query, prompt: "Find", isPrimary: true)

                Text(proxy.matchCount > 0 ? "\(proxy.currentMatch)/\(proxy.matchCount)" : "0")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(theme.gutterForeground))
                    .frame(minWidth: 38)

                Button { proxy.findPrevious() } label: { Image(systemName: "chevron.up") }
                    .disabled(proxy.matchCount == 0)
                Button { proxy.findNext() } label: { Image(systemName: "chevron.down") }
                    .disabled(proxy.matchCount == 0)
                Button {
                    isPresented = false
                    proxy.find("", options: options)
                } label: { Image(systemName: "xmark.circle.fill") }
            }

            if showReplace {
                HStack(spacing: 8) {
                    Spacer().frame(width: 16)
                    field(text: $replacement, prompt: "Replace with", isPrimary: false)
                    Button("Replace") {
                        proxy.replaceCurrent(with: replacement, query: query, options: options)
                    }
                    .disabled(proxy.matchCount == 0)
                    Button("All") {
                        proxy.replaceAll(with: replacement, query: query, options: options)
                    }
                    .disabled(proxy.matchCount == 0)
                }
                .font(.system(size: 13))
            }

            HStack(spacing: 10) {
                toggle("Aa", isOn: $options.caseSensitive, help: "Case sensitive")
                toggle("W", isOn: $options.wholeWord, help: "Whole word")
                toggle(".*", isOn: $options.useRegex, help: "Regular expression")
                Spacer()
            }
            .padding(.leading, 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(theme.gutterBackground))
        .tint(Color(theme.accent))
        .foregroundColor(Color(theme.foreground))
        .onAppear { focused = true }
        .onChange(of: query) { _ in proxy.find(query, options: options) }
        .onChange(of: options) { _ in proxy.find(query, options: options) }
    }

    @ViewBuilder
    private func field(text: Binding<String>, prompt: String, isPrimary: Bool) -> some View {
        if isPrimary {
            baseField(text: text, prompt: prompt).focused($focused)
        } else {
            baseField(text: text, prompt: prompt)
        }
    }

    private func baseField(text: Binding<String>, prompt: String) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.system(size: 14, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(theme.currentLine))
            )
            .submitLabel(.search)
            .onSubmit { proxy.findNext() }
    }

    private func toggle(_ label: String, isOn: Binding<Bool>, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOn.wrappedValue ? Color(theme.accent).opacity(0.28) : Color(theme.currentLine))
                )
                .foregroundColor(isOn.wrappedValue ? Color(theme.accent) : Color(theme.gutterForeground))
        }
        .accessibilityLabel(help)
    }
}
