import UIKit

struct EditorTheme: Identifiable, Equatable {
    var id: String
    var name: String
    var isDark: Bool

    var background: UIColor
    var foreground: UIColor
    var selection: UIColor
    var currentLine: UIColor
    var gutterBackground: UIColor
    var gutterForeground: UIColor
    var gutterActiveForeground: UIColor
    var caret: UIColor
    var indentGuide: UIColor
    var accent: UIColor

    var colors: [TokenType: UIColor]

    func color(for token: TokenType) -> UIColor {
        colors[token] ?? foreground
    }

    static func == (lhs: EditorTheme, rhs: EditorTheme) -> Bool { lhs.id == rhs.id }
}

private func hex(_ value: UInt32) -> UIColor {
    UIColor(red: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0)
}

private func hex(_ value: UInt32, _ alpha: CGFloat) -> UIColor {
    hex(value).withAlphaComponent(alpha)
}

enum Themes {

    static let all: [EditorTheme] = [
        midnight, nova, monokaiPro, dracula, nord, solarizedDark, gruvboxDark, oneDark,
        tokyoNight, catppuccin, github, solarizedLight, xcodeLight, paper, highContrast
    ]

    static func theme(id: String) -> EditorTheme {
        all.first { $0.id == id } ?? midnight
    }

    /// The app's own default — a deep navy tuned for OLED iPhone panels.
    static let midnight = EditorTheme(
        id: "midnight", name: "Midnight", isDark: true,
        background: hex(0x0B0F17), foreground: hex(0xD6DEEB), selection: hex(0x2E4A6B, 0.65),
        currentLine: hex(0x141B27), gutterBackground: hex(0x0B0F17), gutterForeground: hex(0x3D4A5C),
        gutterActiveForeground: hex(0x9CB3D0), caret: hex(0x62B4FF), indentGuide: hex(0x1E2735),
        accent: hex(0x62B4FF),
        colors: [
            .keyword: hex(0xC792EA), .controlKeyword: hex(0xC792EA), .type: hex(0x82AAFF),
            .constant: hex(0xF78C6C), .builtin: hex(0x7FDBCA), .function: hex(0x82AAFF),
            .property: hex(0x80CBC4), .variable: hex(0xD6DEEB), .number: hex(0xF78C6C),
            .string: hex(0xC3E88D), .escape: hex(0xF07178), .interpolation: hex(0xFFCB6B),
            .regex: hex(0x89DDFF), .comment: hex(0x5C6773), .docComment: hex(0x6B7C8F),
            .operator: hex(0x89DDFF), .punctuation: hex(0x8896A8), .preprocessor: hex(0xFFCB6B),
            .annotation: hex(0xFFCB6B), .tag: hex(0xF07178), .attribute: hex(0xFFCB6B),
            .heading: hex(0x82AAFF), .link: hex(0x89DDFF), .emphasis: hex(0xC3E88D),
            .strong: hex(0xFFCB6B), .inserted: hex(0x8CD98C), .deleted: hex(0xF07178),
            .invalid: hex(0xFF5370)
        ])

    static let nova = EditorTheme(
        id: "nova", name: "Nova", isDark: true,
        background: hex(0x11141C), foreground: hex(0xE4E7EF), selection: hex(0x3C4A7A, 0.6),
        currentLine: hex(0x1A1F2B), gutterBackground: hex(0x11141C), gutterForeground: hex(0x434B60),
        gutterActiveForeground: hex(0xB9C2DA), caret: hex(0xFF7A93), indentGuide: hex(0x232838),
        accent: hex(0xFF7A93),
        colors: [
            .keyword: hex(0xFF7A93), .controlKeyword: hex(0xFF9E64), .type: hex(0x7DCFFF),
            .constant: hex(0xBB9AF7), .builtin: hex(0x2AC3DE), .function: hex(0x7AA2F7),
            .property: hex(0x73DACA), .variable: hex(0xE4E7EF), .number: hex(0xFF9E64),
            .string: hex(0x9ECE6A), .escape: hex(0xE0AF68), .interpolation: hex(0xE0AF68),
            .regex: hex(0xB4F9F8), .comment: hex(0x565F89), .docComment: hex(0x6B759B),
            .operator: hex(0x89DDFF), .punctuation: hex(0x9AA5CE), .preprocessor: hex(0xE0AF68),
            .annotation: hex(0xE0AF68), .tag: hex(0xF7768E), .attribute: hex(0xE0AF68),
            .heading: hex(0x7AA2F7), .link: hex(0x2AC3DE), .emphasis: hex(0x9ECE6A),
            .strong: hex(0xE0AF68), .inserted: hex(0x9ECE6A), .deleted: hex(0xF7768E),
            .invalid: hex(0xFF5370)
        ])

    static let monokaiPro = EditorTheme(
        id: "monokai", name: "Monokai Pro", isDark: true,
        background: hex(0x221F22), foreground: hex(0xFCFCFA), selection: hex(0x5B595C, 0.7),
        currentLine: hex(0x2D2A2E), gutterBackground: hex(0x221F22), gutterForeground: hex(0x5B595C),
        gutterActiveForeground: hex(0xC1C0C0), caret: hex(0xFFD866), indentGuide: hex(0x363437),
        accent: hex(0xFF6188),
        colors: [
            .keyword: hex(0xFF6188), .controlKeyword: hex(0xFF6188), .type: hex(0x78DCE8),
            .constant: hex(0xAB9DF2), .builtin: hex(0x78DCE8), .function: hex(0xA9DC76),
            .property: hex(0xFCFCFA), .variable: hex(0xFCFCFA), .number: hex(0xAB9DF2),
            .string: hex(0xFFD866), .escape: hex(0xFC9867), .interpolation: hex(0xFC9867),
            .regex: hex(0xFFD866), .comment: hex(0x727072), .docComment: hex(0x848084),
            .operator: hex(0xFF6188), .punctuation: hex(0x939293), .preprocessor: hex(0xFC9867),
            .annotation: hex(0xFC9867), .tag: hex(0xFF6188), .attribute: hex(0xA9DC76),
            .heading: hex(0xA9DC76), .link: hex(0x78DCE8), .emphasis: hex(0xFFD866),
            .strong: hex(0xFC9867), .inserted: hex(0xA9DC76), .deleted: hex(0xFF6188),
            .invalid: hex(0xFF6188)
        ])

    static let dracula = EditorTheme(
        id: "dracula", name: "Dracula", isDark: true,
        background: hex(0x282A36), foreground: hex(0xF8F8F2), selection: hex(0x44475A, 0.9),
        currentLine: hex(0x313442), gutterBackground: hex(0x282A36), gutterForeground: hex(0x6272A4),
        gutterActiveForeground: hex(0xF8F8F2), caret: hex(0xF8F8F0), indentGuide: hex(0x3A3D4D),
        accent: hex(0xBD93F9),
        colors: [
            .keyword: hex(0xFF79C6), .controlKeyword: hex(0xFF79C6), .type: hex(0x8BE9FD),
            .constant: hex(0xBD93F9), .builtin: hex(0x8BE9FD), .function: hex(0x50FA7B),
            .property: hex(0xF8F8F2), .variable: hex(0xF8F8F2), .number: hex(0xBD93F9),
            .string: hex(0xF1FA8C), .escape: hex(0xFFB86C), .interpolation: hex(0xFFB86C),
            .regex: hex(0xFF5555), .comment: hex(0x6272A4), .docComment: hex(0x7284B8),
            .operator: hex(0xFF79C6), .punctuation: hex(0xF8F8F2), .preprocessor: hex(0xFFB86C),
            .annotation: hex(0xFFB86C), .tag: hex(0xFF79C6), .attribute: hex(0x50FA7B),
            .heading: hex(0x8BE9FD), .link: hex(0x8BE9FD), .emphasis: hex(0xF1FA8C),
            .strong: hex(0xFFB86C), .inserted: hex(0x50FA7B), .deleted: hex(0xFF5555),
            .invalid: hex(0xFF5555)
        ])

    static let nord = EditorTheme(
        id: "nord", name: "Nord", isDark: true,
        background: hex(0x2E3440), foreground: hex(0xD8DEE9), selection: hex(0x434C5E, 0.9),
        currentLine: hex(0x3B4252), gutterBackground: hex(0x2E3440), gutterForeground: hex(0x4C566A),
        gutterActiveForeground: hex(0xD8DEE9), caret: hex(0x88C0D0), indentGuide: hex(0x3B4252),
        accent: hex(0x88C0D0),
        colors: [
            .keyword: hex(0x81A1C1), .controlKeyword: hex(0x81A1C1), .type: hex(0x8FBCBB),
            .constant: hex(0xB48EAD), .builtin: hex(0x88C0D0), .function: hex(0x88C0D0),
            .property: hex(0xD8DEE9), .variable: hex(0xD8DEE9), .number: hex(0xB48EAD),
            .string: hex(0xA3BE8C), .escape: hex(0xEBCB8B), .interpolation: hex(0xEBCB8B),
            .regex: hex(0xEBCB8B), .comment: hex(0x616E88), .docComment: hex(0x6E7D96),
            .operator: hex(0x81A1C1), .punctuation: hex(0xECEFF4), .preprocessor: hex(0x5E81AC),
            .annotation: hex(0xD08770), .tag: hex(0x81A1C1), .attribute: hex(0x8FBCBB),
            .heading: hex(0x88C0D0), .link: hex(0x8FBCBB), .emphasis: hex(0xA3BE8C),
            .strong: hex(0xEBCB8B), .inserted: hex(0xA3BE8C), .deleted: hex(0xBF616A),
            .invalid: hex(0xBF616A)
        ])

    static let solarizedDark = EditorTheme(
        id: "solarized-dark", name: "Solarized Dark", isDark: true,
        background: hex(0x002B36), foreground: hex(0x93A1A1), selection: hex(0x073642, 0.95),
        currentLine: hex(0x073642), gutterBackground: hex(0x002B36), gutterForeground: hex(0x586E75),
        gutterActiveForeground: hex(0x93A1A1), caret: hex(0x2AA198), indentGuide: hex(0x073642),
        accent: hex(0x268BD2),
        colors: [
            .keyword: hex(0x859900), .controlKeyword: hex(0x859900), .type: hex(0xB58900),
            .constant: hex(0xD33682), .builtin: hex(0x2AA198), .function: hex(0x268BD2),
            .property: hex(0x93A1A1), .variable: hex(0x93A1A1), .number: hex(0xD33682),
            .string: hex(0x2AA198), .escape: hex(0xCB4B16), .interpolation: hex(0xCB4B16),
            .regex: hex(0xDC322F), .comment: hex(0x586E75), .docComment: hex(0x657B83),
            .operator: hex(0x859900), .punctuation: hex(0x93A1A1), .preprocessor: hex(0xCB4B16),
            .annotation: hex(0xB58900), .tag: hex(0x268BD2), .attribute: hex(0xB58900),
            .heading: hex(0x268BD2), .link: hex(0x2AA198), .emphasis: hex(0x2AA198),
            .strong: hex(0xB58900), .inserted: hex(0x859900), .deleted: hex(0xDC322F),
            .invalid: hex(0xDC322F)
        ])

    static let gruvboxDark = EditorTheme(
        id: "gruvbox", name: "Gruvbox Dark", isDark: true,
        background: hex(0x282828), foreground: hex(0xEBDBB2), selection: hex(0x504945, 0.9),
        currentLine: hex(0x32302F), gutterBackground: hex(0x282828), gutterForeground: hex(0x665C54),
        gutterActiveForeground: hex(0xEBDBB2), caret: hex(0xFE8019), indentGuide: hex(0x3C3836),
        accent: hex(0xFE8019),
        colors: [
            .keyword: hex(0xFB4934), .controlKeyword: hex(0xFB4934), .type: hex(0xFABD2F),
            .constant: hex(0xD3869B), .builtin: hex(0x8EC07C), .function: hex(0xB8BB26),
            .property: hex(0xEBDBB2), .variable: hex(0x83A598), .number: hex(0xD3869B),
            .string: hex(0xB8BB26), .escape: hex(0xFE8019), .interpolation: hex(0xFE8019),
            .regex: hex(0xFE8019), .comment: hex(0x928374), .docComment: hex(0xA89984),
            .operator: hex(0xFE8019), .punctuation: hex(0xEBDBB2), .preprocessor: hex(0x8EC07C),
            .annotation: hex(0xFABD2F), .tag: hex(0xFB4934), .attribute: hex(0xFABD2F),
            .heading: hex(0xB8BB26), .link: hex(0x83A598), .emphasis: hex(0xB8BB26),
            .strong: hex(0xFABD2F), .inserted: hex(0xB8BB26), .deleted: hex(0xFB4934),
            .invalid: hex(0xFB4934)
        ])

    static let oneDark = EditorTheme(
        id: "one-dark", name: "One Dark", isDark: true,
        background: hex(0x282C34), foreground: hex(0xABB2BF), selection: hex(0x3E4451, 0.95),
        currentLine: hex(0x2C313A), gutterBackground: hex(0x282C34), gutterForeground: hex(0x4B5263),
        gutterActiveForeground: hex(0xABB2BF), caret: hex(0x528BFF), indentGuide: hex(0x3B4048),
        accent: hex(0x61AFEF),
        colors: [
            .keyword: hex(0xC678DD), .controlKeyword: hex(0xC678DD), .type: hex(0xE5C07B),
            .constant: hex(0xD19A66), .builtin: hex(0x56B6C2), .function: hex(0x61AFEF),
            .property: hex(0xE06C75), .variable: hex(0xE06C75), .number: hex(0xD19A66),
            .string: hex(0x98C379), .escape: hex(0x56B6C2), .interpolation: hex(0xE5C07B),
            .regex: hex(0x98C379), .comment: hex(0x5C6370), .docComment: hex(0x7F848E),
            .operator: hex(0x56B6C2), .punctuation: hex(0xABB2BF), .preprocessor: hex(0xC678DD),
            .annotation: hex(0xE5C07B), .tag: hex(0xE06C75), .attribute: hex(0xD19A66),
            .heading: hex(0x61AFEF), .link: hex(0x56B6C2), .emphasis: hex(0x98C379),
            .strong: hex(0xE5C07B), .inserted: hex(0x98C379), .deleted: hex(0xE06C75),
            .invalid: hex(0xE06C75)
        ])

    static let tokyoNight = EditorTheme(
        id: "tokyo-night", name: "Tokyo Night", isDark: true,
        background: hex(0x1A1B26), foreground: hex(0xA9B1D6), selection: hex(0x28344A, 0.95),
        currentLine: hex(0x1F2335), gutterBackground: hex(0x1A1B26), gutterForeground: hex(0x3B4261),
        gutterActiveForeground: hex(0x737AA2), caret: hex(0xC0CAF5), indentGuide: hex(0x292E42),
        accent: hex(0x7AA2F7),
        colors: [
            .keyword: hex(0xBB9AF7), .controlKeyword: hex(0xBB9AF7), .type: hex(0x2AC3DE),
            .constant: hex(0xFF9E64), .builtin: hex(0x7DCFFF), .function: hex(0x7AA2F7),
            .property: hex(0x73DACA), .variable: hex(0xC0CAF5), .number: hex(0xFF9E64),
            .string: hex(0x9ECE6A), .escape: hex(0xE0AF68), .interpolation: hex(0xE0AF68),
            .regex: hex(0xB4F9F8), .comment: hex(0x565F89), .docComment: hex(0x627099),
            .operator: hex(0x89DDFF), .punctuation: hex(0x9ABDF5), .preprocessor: hex(0xE0AF68),
            .annotation: hex(0xE0AF68), .tag: hex(0xF7768E), .attribute: hex(0xE0AF68),
            .heading: hex(0x7AA2F7), .link: hex(0x2AC3DE), .emphasis: hex(0x9ECE6A),
            .strong: hex(0xE0AF68), .inserted: hex(0x9ECE6A), .deleted: hex(0xF7768E),
            .invalid: hex(0xFF5370)
        ])

    static let catppuccin = EditorTheme(
        id: "catppuccin", name: "Catppuccin Mocha", isDark: true,
        background: hex(0x1E1E2E), foreground: hex(0xCDD6F4), selection: hex(0x45475A, 0.95),
        currentLine: hex(0x252539), gutterBackground: hex(0x1E1E2E), gutterForeground: hex(0x585B70),
        gutterActiveForeground: hex(0xBAC2DE), caret: hex(0xF5E0DC), indentGuide: hex(0x313244),
        accent: hex(0xCBA6F7),
        colors: [
            .keyword: hex(0xCBA6F7), .controlKeyword: hex(0xCBA6F7), .type: hex(0xF9E2AF),
            .constant: hex(0xFAB387), .builtin: hex(0x89DCEB), .function: hex(0x89B4FA),
            .property: hex(0x94E2D5), .variable: hex(0xCDD6F4), .number: hex(0xFAB387),
            .string: hex(0xA6E3A1), .escape: hex(0xF5C2E7), .interpolation: hex(0xF5C2E7),
            .regex: hex(0xF5C2E7), .comment: hex(0x6C7086), .docComment: hex(0x7F849C),
            .operator: hex(0x89DCEB), .punctuation: hex(0xBAC2DE), .preprocessor: hex(0xF38BA8),
            .annotation: hex(0xF9E2AF), .tag: hex(0xF38BA8), .attribute: hex(0xF9E2AF),
            .heading: hex(0x89B4FA), .link: hex(0x89DCEB), .emphasis: hex(0xA6E3A1),
            .strong: hex(0xF9E2AF), .inserted: hex(0xA6E3A1), .deleted: hex(0xF38BA8),
            .invalid: hex(0xF38BA8)
        ])

    static let highContrast = EditorTheme(
        id: "high-contrast", name: "High Contrast", isDark: true,
        background: hex(0x000000), foreground: hex(0xFFFFFF), selection: hex(0x264F78, 1.0),
        currentLine: hex(0x1A1A1A), gutterBackground: hex(0x000000), gutterForeground: hex(0x8A8A8A),
        gutterActiveForeground: hex(0xFFFFFF), caret: hex(0xFFFF00), indentGuide: hex(0x333333),
        accent: hex(0x00FFFF),
        colors: [
            .keyword: hex(0x00FFFF), .controlKeyword: hex(0xFF80FF), .type: hex(0x80FF80),
            .constant: hex(0xFFFF00), .builtin: hex(0x00FF9F), .function: hex(0xFFD700),
            .property: hex(0xFFFFFF), .variable: hex(0xFFFFFF), .number: hex(0xFF9E64),
            .string: hex(0x9CFF9C), .escape: hex(0xFF7070), .interpolation: hex(0xFFFF00),
            .regex: hex(0xFFA0FF), .comment: hex(0x9E9E9E), .docComment: hex(0xB0B0B0),
            .operator: hex(0x00FFFF), .punctuation: hex(0xFFFFFF), .preprocessor: hex(0xFFFF00),
            .annotation: hex(0xFFFF00), .tag: hex(0x00FFFF), .attribute: hex(0x80FF80),
            .heading: hex(0xFFD700), .link: hex(0x00FFFF), .emphasis: hex(0x9CFF9C),
            .strong: hex(0xFFFF00), .inserted: hex(0x00FF00), .deleted: hex(0xFF5050),
            .invalid: hex(0xFF0000)
        ])

    // MARK: - Light themes

    static let github = EditorTheme(
        id: "github", name: "GitHub Light", isDark: false,
        background: hex(0xFFFFFF), foreground: hex(0x24292F), selection: hex(0xADD6FF, 0.7),
        currentLine: hex(0xF6F8FA), gutterBackground: hex(0xFFFFFF), gutterForeground: hex(0x8C959F),
        gutterActiveForeground: hex(0x24292F), caret: hex(0x0969DA), indentGuide: hex(0xEAEEF2),
        accent: hex(0x0969DA),
        colors: [
            .keyword: hex(0xCF222E), .controlKeyword: hex(0xCF222E), .type: hex(0x953800),
            .constant: hex(0x0550AE), .builtin: hex(0x8250DF), .function: hex(0x8250DF),
            .property: hex(0x0550AE), .variable: hex(0x24292F), .number: hex(0x0550AE),
            .string: hex(0x0A3069), .escape: hex(0x116329), .interpolation: hex(0x953800),
            .regex: hex(0x0A3069), .comment: hex(0x6E7781), .docComment: hex(0x57606A),
            .operator: hex(0xCF222E), .punctuation: hex(0x24292F), .preprocessor: hex(0x8250DF),
            .annotation: hex(0x953800), .tag: hex(0x116329), .attribute: hex(0x0550AE),
            .heading: hex(0x0550AE), .link: hex(0x0969DA), .emphasis: hex(0x24292F),
            .strong: hex(0x24292F), .inserted: hex(0x116329), .deleted: hex(0xCF222E),
            .invalid: hex(0xCF222E)
        ])

    static let solarizedLight = EditorTheme(
        id: "solarized-light", name: "Solarized Light", isDark: false,
        background: hex(0xFDF6E3), foreground: hex(0x657B83), selection: hex(0xEEE8D5, 1.0),
        currentLine: hex(0xEEE8D5), gutterBackground: hex(0xFDF6E3), gutterForeground: hex(0x93A1A1),
        gutterActiveForeground: hex(0x586E75), caret: hex(0x2AA198), indentGuide: hex(0xEEE8D5),
        accent: hex(0x268BD2),
        colors: [
            .keyword: hex(0x859900), .controlKeyword: hex(0x859900), .type: hex(0xB58900),
            .constant: hex(0xD33682), .builtin: hex(0x2AA198), .function: hex(0x268BD2),
            .property: hex(0x657B83), .variable: hex(0x657B83), .number: hex(0xD33682),
            .string: hex(0x2AA198), .escape: hex(0xCB4B16), .interpolation: hex(0xCB4B16),
            .regex: hex(0xDC322F), .comment: hex(0x93A1A1), .docComment: hex(0x839496),
            .operator: hex(0x859900), .punctuation: hex(0x657B83), .preprocessor: hex(0xCB4B16),
            .annotation: hex(0xB58900), .tag: hex(0x268BD2), .attribute: hex(0xB58900),
            .heading: hex(0x268BD2), .link: hex(0x2AA198), .emphasis: hex(0x2AA198),
            .strong: hex(0xB58900), .inserted: hex(0x859900), .deleted: hex(0xDC322F),
            .invalid: hex(0xDC322F)
        ])

    static let xcodeLight = EditorTheme(
        id: "xcode-light", name: "Xcode Light", isDark: false,
        background: hex(0xFFFFFF), foreground: hex(0x1F1F24), selection: hex(0xB2D7FF, 0.8),
        currentLine: hex(0xECF5FF), gutterBackground: hex(0xFFFFFF), gutterForeground: hex(0xA0A0A5),
        gutterActiveForeground: hex(0x1F1F24), caret: hex(0x0F68A0), indentGuide: hex(0xE8E8ED),
        accent: hex(0x0F68A0),
        colors: [
            .keyword: hex(0xAD3DA4), .controlKeyword: hex(0xAD3DA4), .type: hex(0x0B4F79),
            .constant: hex(0x272AD8), .builtin: hex(0x804FB8), .function: hex(0x326D74),
            .property: hex(0x326D74), .variable: hex(0x1F1F24), .number: hex(0x272AD8),
            .string: hex(0xD12F1B), .escape: hex(0x804FB8), .interpolation: hex(0x1F1F24),
            .regex: hex(0xD12F1B), .comment: hex(0x5D6C79), .docComment: hex(0x3F7043),
            .operator: hex(0x1F1F24), .punctuation: hex(0x1F1F24), .preprocessor: hex(0x78492A),
            .annotation: hex(0x78492A), .tag: hex(0xAD3DA4), .attribute: hex(0x326D74),
            .heading: hex(0x0B4F79), .link: hex(0x0F68A0), .emphasis: hex(0x1F1F24),
            .strong: hex(0x1F1F24), .inserted: hex(0x3F7043), .deleted: hex(0xD12F1B),
            .invalid: hex(0xD12F1B)
        ])

    static let paper = EditorTheme(
        id: "paper", name: "Paper", isDark: false,
        background: hex(0xF7F5EF), foreground: hex(0x35322D), selection: hex(0xD9D2C2, 1.0),
        currentLine: hex(0xEDEAE1), gutterBackground: hex(0xF7F5EF), gutterForeground: hex(0xAFA894),
        gutterActiveForeground: hex(0x35322D), caret: hex(0xB2541F), indentGuide: hex(0xE4DFD2),
        accent: hex(0xB2541F),
        colors: [
            .keyword: hex(0x8A3F3F), .controlKeyword: hex(0x8A3F3F), .type: hex(0x2E6E64),
            .constant: hex(0x7A4FB0), .builtin: hex(0x2E6E64), .function: hex(0x2C5C8A),
            .property: hex(0x35322D), .variable: hex(0x35322D), .number: hex(0x7A4FB0),
            .string: hex(0x4F7A3F), .escape: hex(0xB2541F), .interpolation: hex(0xB2541F),
            .regex: hex(0x4F7A3F), .comment: hex(0x8E8878), .docComment: hex(0x7D7768),
            .operator: hex(0x8A3F3F), .punctuation: hex(0x5F5A50), .preprocessor: hex(0xB2541F),
            .annotation: hex(0xB2541F), .tag: hex(0x8A3F3F), .attribute: hex(0x2C5C8A),
            .heading: hex(0x2C5C8A), .link: hex(0x2C5C8A), .emphasis: hex(0x4F7A3F),
            .strong: hex(0xB2541F), .inserted: hex(0x4F7A3F), .deleted: hex(0x8A3F3F),
            .invalid: hex(0xC0392B)
        ])
}
